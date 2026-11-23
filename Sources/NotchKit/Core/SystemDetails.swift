import CoreGraphics
import Foundation

/// The extra readings the Stats panel shows (the notch itself only needs memory and CPU).
/// Everything here is read on this Mac with ordinary system calls; nothing is sent anywhere.
public struct SystemDetails: Equatable, Sendable {
    /// User and system shares of all cores, 0…1.
    public var cpuUser: Double = 0
    public var cpuSystem: Double = 0
    /// Each core's share, 0…1, in the order macOS numbers them.
    public var coreLoads: [Double] = []
    /// 1, 5 and 15 minute load averages.
    public var loadAverage: [Double] = []
    public var swapUsed: UInt64 = 0
    public var memoryApp: UInt64 = 0
    public var memoryWired: UInt64 = 0
    public var memoryCompressed: UInt64 = 0
    /// GPU utilisation, 0…1, when the graphics driver reports it.
    public var gpu: Double?
    public var battery: BatteryInfo?
    /// 0 nominal, 1 fair, 2 serious, 3 critical (ProcessInfo.ThermalState).
    public var thermal: Int = 0
    public var uptime: TimeInterval = 0
    public var localAddress: String?
    /// Busiest apps, most first.
    public var topProcesses: [ProcessLoad] = []

    public init() {}
}

/// One app's CPU use, as Activity Monitor shows it: 100% is one full core.
public struct ProcessLoad: Equatable, Sendable, Identifiable {
    public var pid: Int32
    public var name: String
    public var cpu: Double
    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpu: Double) {
        self.pid = pid
        self.name = name
        self.cpu = cpu
    }
}

/// The battery, from the AppleSmartBattery entry in the I/O Registry.
public struct BatteryInfo: Equatable, Sendable {
    public var level: Int
    public var isCharging: Bool
    public var onPower: Bool
    /// Minutes to empty (or full while charging); nil while macOS is still estimating.
    public var minutesRemaining: Int?
    public var cycleCount: Int?
    /// Full-charge capacity as a share of the design capacity, 0…1.
    public var health: Double?
    /// Degrees Celsius.
    public var temperature: Double?
    /// Watts flowing out of (negative) or into (positive) the battery.
    public var watts: Double?
    /// The charger's rating, when one is connected.
    public var adapterWatts: Int?

    public init(level: Int, isCharging: Bool, onPower: Bool, minutesRemaining: Int? = nil, cycleCount: Int? = nil,
                health: Double? = nil, temperature: Double? = nil, watts: Double? = nil, adapterWatts: Int? = nil) {
        self.level = level
        self.isCharging = isCharging
        self.onPower = onPower
        self.minutesRemaining = minutesRemaining
        self.cycleCount = cycleCount
        self.health = health
        self.temperature = temperature
        self.watts = watts
        self.adapterWatts = adapterWatts
    }

    /// Reads the registry entry's properties. Nil when there's no battery (a desktop Mac).
    public static func parse(_ properties: [String: Any]) -> BatteryInfo? {
        // Apple silicon keeps some readings in a nested "BatteryData" dictionary.
        let nested = properties["BatteryData"] as? [String: Any] ?? [:]
        func int(_ key: String) -> Int? { ((properties[key] ?? nested[key]) as? NSNumber)?.intValue }
        guard let current = int("CurrentCapacity"), let max = int("MaxCapacity"), max > 0 else { return nil }
        // Apple silicon reports percentages here; Intel reports mAh. Either way this is the level.
        let level = Swift.min(100, Swift.max(0, Int((Double(current) / Double(max) * 100).rounded())))
        let isCharging = (properties["IsCharging"] as? Bool) ?? false
        let onPower = (properties["ExternalConnected"] as? Bool) ?? false
        let remaining = int("TimeRemaining").flatMap { (1..<6000).contains($0) ? $0 : nil }
        let fullMAh = int("AppleRawMaxCapacity") ?? int("NominalChargeCapacity")
        let health = fullMAh.flatMap { full in int("DesignCapacity").flatMap { $0 > 0 ? Swift.min(1, Double(full) / Double($0)) : nil } }
        let temperature = int("Temperature").map { Double($0) / 100 }
        var watts: Double?
        if let millivolts = int("Voltage"), let milliamps = int("InstantAmperage") ?? int("Amperage") {
            // Amperage is a signed 64-bit value that some Macs report as a huge unsigned number.
            let signed = milliamps > Int(Int32.max) ? milliamps - Int(UInt32.max) - 1 : milliamps
            watts = Double(millivolts) * Double(signed) / 1_000_000
        }
        let adapter = (properties["AdapterDetails"] as? [String: Any]).flatMap { ($0["Watts"] as? NSNumber)?.intValue }
        return BatteryInfo(level: level, isCharging: isCharging, onPower: onPower, minutesRemaining: remaining,
                           cycleCount: int("CycleCount"), health: health, temperature: temperature, watts: watts,
                           adapterWatts: onPower ? adapter : nil)
    }
}

extension StatsMath {
    /// GPU utilisation from an IOAccelerator's "PerformanceStatistics", 0…1.
    public static func gpuUtilization(_ statistics: [String: Any]) -> Double? {
        let value = (statistics["Device Utilization %"] as? NSNumber) ?? (statistics["GPU Activity(%)"] as? NSNumber)
        return value.map { min(1, max(0, $0.doubleValue / 100)) }
    }

    /// CPU per process from two readings of cumulative CPU time (nanoseconds), busiest first.
    /// Processes that only appear in one reading are skipped; a counter that went backwards
    /// (a reused pid) reads as idle.
    public static func topProcesses(old: [Int32: UInt64], new: [Int32: UInt64], names: [Int32: String],
                                    seconds: TimeInterval, limit: Int = 4) -> [ProcessLoad] {
        guard seconds > 0 else { return [] }
        let loads = new.compactMap { pid, time -> ProcessLoad? in
            guard let before = old[pid], time > before else { return nil }
            let cpu = Double(time - before) / 1_000_000_000 / seconds
            guard cpu >= 0.005 else { return nil }
            return ProcessLoad(pid: pid, name: names[pid] ?? "pid \(pid)", cpu: cpu)
        }
        return Array(loads.sorted { $0.cpu == $1.cpu ? $0.pid < $1.pid : $0.cpu > $1.cpu }.prefix(limit))
    }

    /// "3d 4h", "5h 12m", "18m".
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(0, seconds) / 60)
        let days = minutes / 1440, hours = (minutes % 1440) / 60, mins = minutes % 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }

    /// The last `limit` readings, oldest first, for a sparkline.
    public static func appending(_ value: Double, to history: [Double], limit: Int = 60) -> [Double] {
        Array((history + [value]).suffix(limit))
    }

    public static func thermalLabel(_ state: Int) -> String {
        switch state {
        case 1: String(localized: "Warm")
        case 2: String(localized: "Hot")
        case 3: String(localized: "Critical")
        default: String(localized: "Cool")
        }
    }
}

/// Where a sparkline's points go: newest on the right, the full history across the width.
public enum SparklineMath {
    public static func points(_ values: [Double], in size: CGSize, normalize: Bool, slots: Int = 60) -> [CGPoint] {
        guard values.count > 1, size.width > 0, size.height > 0 else { return [] }
        let top = normalize ? max(values.max() ?? 0, 1) : 1
        let step = size.width / CGFloat(max(slots - 1, 1))
        let start = size.width - step * CGFloat(values.count - 1)
        return values.enumerated().map { index, value in
            let share = min(1, max(0, value / top))
            return CGPoint(x: start + step * CGFloat(index), y: size.height - size.height * share)
        }
    }
}
