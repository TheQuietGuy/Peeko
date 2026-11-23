import AppKit
import Darwin
import IOKit

/// The system calls behind the Stats panel's details. Each is cheap and runs only while the
/// panel is open.
enum SystemReaders {
    /// Asked for once: every `mach_host_self()` call hands out a port right that must be released.
    private static let host = mach_host_self()

    /// Per-core tick counters (user, system, idle, nice), one entry per core.
    static func coreTicks() -> [StatsMath.CPUTicks]? {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        let states = Int(CPU_STATE_MAX)
        return (0..<Int(count)).map { core in
            let base = core * states
            return StatsMath.CPUTicks(
                user: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])),
                system: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)])),
                idle: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])),
                nice: UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
            )
        }
    }

    static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : []
    }

    static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    /// App, wired and compressed memory, like Activity Monitor's breakdown.
    static func memoryBreakdown() -> (app: UInt64, wired: UInt64, compressed: UInt64)? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = UInt64(getpagesize())
        let app = UInt64(info.internal_page_count) - min(UInt64(info.internal_page_count), UInt64(info.purgeable_count))
        return (app * page, UInt64(info.wire_count) * page, UInt64(info.compressor_page_count) * page)
    }

    /// The first graphics device that reports how busy it is.
    static func gpuUtilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any]
            IOObjectRelease(service)
            if let stats, let value = StatsMath.gpuUtilization(stats) { return value }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    static func battery() -> BatteryInfo? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any] else { return nil }
        return BatteryInfo.parse(dictionary)
    }

    /// The Mac's address on the local network (Wi-Fi or Ethernet), for sharing or debugging.
    static func localAddress() -> String? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard StatsMath.countsTraffic(interface: String(cString: entry.ifa_name)),
                  let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  Int32(entry.ifa_flags) & IFF_UP != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            return Self.string(host)
        }
        return nil
    }

    /// Cumulative CPU time (nanoseconds) of every process this user can see.
    static func processTimes() -> [Int32: UInt64] {
        let capacity = Int(proc_listallpids(nil, 0)) + 64
        guard capacity > 64 else { return [:] }
        var pids = [Int32](repeating: 0, count: capacity)
        let filled = Int(proc_listallpids(&pids, Int32(capacity * MemoryLayout<Int32>.size)))
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        var times: [Int32: UInt64] = [:]
        for pid in pids.prefix(max(0, filled)) where pid > 0 {
            var usage = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            }
            guard ok == 0 else { continue }
            // These counters are in Mach time units: nanoseconds on Intel, not on Apple silicon.
            let ticks = usage.ri_user_time + usage.ri_system_time
            times[pid] = ticks * UInt64(timebase.numer) / UInt64(max(1, timebase.denom))
        }
        return times
    }

    /// A readable name: the app's own for apps, the process name for everything else.
    static func processName(_ pid: Int32) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.localizedName { return name }
        var buffer = [CChar](repeating: 0, count: 256)
        return proc_name(pid, &buffer, UInt32(buffer.count)) > 0 ? Self.string(buffer) : "pid \(pid)"
    }

    /// A C string buffer, up to its terminating zero.
    private static func string(_ buffer: [CChar]) -> String {
        String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
