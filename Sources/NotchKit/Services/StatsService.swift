import AppKit
import Darwin
import Observation

/// Reads CPU, memory, disk and network every couple of seconds, only while Stats is switched on.
/// Every reading is a handful of cheap kernel calls; nothing is stored or sent anywhere.
@MainActor
@Observable
public final class StatsService {
    public private(set) var snapshot = SystemSnapshot()
    /// False until two readings exist, since CPU and network need a difference to measure.
    public private(set) var hasReading = false
    /// The panel's extra readings; filled only while `detailed` is on.
    public private(set) var details = SystemDetails()
    /// The last two minutes, oldest first, for the panel's sparklines.
    public private(set) var cpuHistory: [Double] = []
    public private(set) var gpuHistory: [Double] = []
    public private(set) var networkInHistory: [Double] = []
    public private(set) var networkOutHistory: [Double] = []

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastTicks: StatsMath.CPUTicks?
    @ObservationIgnored private var lastNetwork: (received: UInt64, sent: UInt64, at: Date)?
    @ObservationIgnored private var lastDiskCheck = Date.distantPast
    @ObservationIgnored private var lastCores: [StatsMath.CPUTicks]?
    @ObservationIgnored private var lastProcesses: (times: [Int32: UInt64], at: Date)?
    @ObservationIgnored private var lastAddressCheck = Date.distantPast
    @ObservationIgnored private var lastBatteryCheck = Date.distantPast
    /// Something is showing Stats; the timer runs only while this is true and the screen is on.
    @ObservationIgnored private var wanted = false
    @ObservationIgnored private var screenAsleep = false

    /// Also read disk and network, for the panel. The notch itself shows only memory and CPU.
    @ObservationIgnored public var detailed = false {
        didSet {
            guard detailed != oldValue else { return }
            // Start network over, so the first rate isn't an average over the time it was off.
            lastNetwork = nil
            if detailed, timer != nil { sample() }
        }
    }

    static let interval: TimeInterval = 2
    /// Asked for once: every `mach_host_self()` call hands out a port right that must be released.
    private static let host = mach_host_self()
    private static let pageSize = UInt64(getpagesize())
    private static let memoryTotal = ProcessInfo.processInfo.physicalMemory

    public init() {
        // No one sees the numbers while the display sleeps, so don't read them.
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setScreenAsleep(true) }
        }
        center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setScreenAsleep(false) }
        }
    }

    public var isRunning: Bool { timer != nil }

    public func start() {
        wanted = true
        schedule()
    }

    /// Stops reading for a while (something else is in the notch) but keeps the last counters,
    /// so the first reading after resuming is already a real one.
    public func pause() {
        wanted = false
        schedule()
    }

    public func stop() {
        pause()
        lastTicks = nil
        lastNetwork = nil
        lastCores = nil
        lastProcesses = nil
        hasReading = false
    }

    private func setScreenAsleep(_ asleep: Bool) {
        screenAsleep = asleep
        schedule()
    }

    private func schedule() {
        let run = wanted && !screenAsleep
        if !run {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        sample()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func sample() {
        var next = snapshot
        let now = Date()
        var measuredChange = false
        var split: (user: Double, system: Double)?
        if let ticks = Self.cpuTicks() {
            if let lastTicks {
                next.cpu = StatsMath.cpuUsage(from: lastTicks, to: ticks)
                split = StatsMath.cpuSplit(from: lastTicks, to: ticks)
                measuredChange = true
                cpuHistory = StatsMath.appending(next.cpu, to: cpuHistory)
            }
            lastTicks = ticks
        }
        if let memory = Self.memoryUsed() {
            next.memoryUsed = memory
        }
        next.memoryPressure = Self.memoryPressure()
        next.memoryTotal = Self.memoryTotal
        if detailed, let network = Self.networkBytes() {
            if let last = lastNetwork {
                let seconds = now.timeIntervalSince(last.at)
                next.networkIn = StatsMath.rate(from: last.received, to: network.received, seconds: seconds)
                next.networkOut = StatsMath.rate(from: last.sent, to: network.sent, seconds: seconds)
            }
            lastNetwork = (network.received, network.sent, now)
        }
        // Free space barely moves; once a minute is plenty.
        if detailed, now.timeIntervalSince(lastDiskCheck) > 60, let disk = Self.disk() {
            next.diskFree = disk.free
            next.diskTotal = disk.total
            lastDiskCheck = now
        }
        if detailed {
            sampleDetails(now: now, split: split, networkIn: next.networkIn, networkOut: next.networkOut)
        }
        if next != snapshot { snapshot = next }
        if measuredChange, !hasReading { hasReading = true }
    }

    /// Everything the panel shows beyond the notch's two numbers.
    private func sampleDetails(now: Date, split: (user: Double, system: Double)?, networkIn: Double, networkOut: Double) {
        var next = details
        if let split {
            next.cpuUser = split.user
            next.cpuSystem = split.system
        }
        if let cores = SystemReaders.coreTicks() {
            if let lastCores, lastCores.count == cores.count {
                next.coreLoads = zip(lastCores, cores).map { StatsMath.cpuUsage(from: $0, to: $1) }
            }
            lastCores = cores
        }
        next.loadAverage = SystemReaders.loadAverage()
        next.swapUsed = SystemReaders.swapUsed()
        if let memory = SystemReaders.memoryBreakdown() {
            next.memoryApp = memory.app
            next.memoryWired = memory.wired
            next.memoryCompressed = memory.compressed
        }
        next.gpu = SystemReaders.gpuUtilization()
        if let gpu = next.gpu { gpuHistory = StatsMath.appending(gpu, to: gpuHistory) }
        // The battery's whole registry entry is large and changes slowly: every 20 s is plenty.
        if now.timeIntervalSince(lastBatteryCheck) > 20 {
            next.battery = SystemReaders.battery()
            lastBatteryCheck = now
        }
        next.thermal = ProcessInfo.processInfo.thermalState.rawValue
        next.uptime = ProcessInfo.processInfo.systemUptime
        if now.timeIntervalSince(lastAddressCheck) > 30 {
            next.localAddress = SystemReaders.localAddress()
            lastAddressCheck = now
        }
        let times = SystemReaders.processTimes()
        if let last = lastProcesses {
            let top = StatsMath.topProcesses(old: last.times, new: times, names: [:], seconds: now.timeIntervalSince(last.at))
            next.topProcesses = top.map { load in
                var load = load
                load.name = SystemReaders.processName(load.pid)
                return load
            }
        }
        lastProcesses = (times, now)
        if lastNetwork != nil {
            networkInHistory = StatsMath.appending(networkIn, to: networkInHistory)
            networkOutHistory = StatsMath.appending(networkOut, to: networkOutHistory)
        }
        if next != details { details = next }
    }

    // MARK: System calls

    private static func cpuTicks() -> StatsMath.CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return StatsMath.CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    /// App memory (anonymous pages that can't be purged), wired and compressed, like the
    /// "Memory Used" figure in Activity Monitor.
    private static func memoryUsed() -> UInt64? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = pageSize
        let app = UInt64(info.internal_page_count) - min(UInt64(info.internal_page_count), UInt64(info.purgeable_count))
        return (app + UInt64(info.wire_count) + UInt64(info.compressor_page_count)) * page
    }

    /// Total bytes in and out across the network interfaces that are up, loopback excluded.
    private static func networkBytes() -> (received: UInt64, sent: UInt64)? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            let flags = Int32(entry.ifa_flags)
            guard StatsMath.countsTraffic(interface: String(cString: entry.ifa_name)),
                  entry.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let data = entry.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            received += UInt64(data.pointee.ifi_ibytes)
            sent += UInt64(data.pointee.ifi_obytes)
        }
        return (received, sent)
    }

    private static func memoryPressure() -> StatsMath.Level {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        return StatsMath.pressure(level)
    }

    private static func disk() -> (free: Int64, total: Int64)? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let free = values.volumeAvailableCapacityForImportantUsage,
              let total = values.volumeTotalCapacity else { return nil }
        return (free, Int64(total))
    }
}
