import Foundation

/// Battery levels of connected Bluetooth audio devices, read from
/// `system_profiler -json SPBluetoothDataType` (macOS has no public API for AirPods levels).
public enum BluetoothBattery {
    /// The level to show for the device called `name`: the lower earbud for AirPods-style
    /// devices, otherwise the main battery. The case is left out: it's not what you're wearing.
    /// Nil when the device isn't connected or reports no battery.
    public static func level(named name: String, inSystemProfilerJSON data: Data) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }
        let wanted = name.lowercased()
        for controller in controllers {
            for entry in controller["device_connected"] as? [[String: Any]] ?? [] {
                for (deviceName, value) in entry where deviceName.lowercased() == wanted {
                    guard let info = value as? [String: Any] else { continue }
                    let buds = ["device_batteryLevelLeft", "device_batteryLevelRight"].compactMap { percent(info[$0]) }
                    if let lowest = buds.min() { return lowest }
                    return percent(info["device_batteryLevelMain"])
                }
            }
        }
        return nil
    }

    /// "85%" → 85. Anything else → nil.
    static func percent(_ value: Any?) -> Int? {
        guard let text = value as? String, text.hasSuffix("%"), let number = Int(text.dropLast()) else { return nil }
        return (0...100).contains(number) ? number : nil
    }
}
