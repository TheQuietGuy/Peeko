import CoreAudio
import Foundation

/// Reports when Bluetooth headphones become the sound output, like the iPhone's AirPods alert.
@MainActor
public final class AudioRouteMonitor {
    public var onAlert: ((IslandAlert) -> Void)?

    private var currentDevice: AudioDeviceID = 0
    private var listener: AudioHW.Listener?
    /// AirPods re-register when they switch to the call profile; don't announce them twice.
    private var lastAnnounced: (name: String, date: Date)?

    public init() {}

    public func start() {
        guard listener == nil else { return }
        currentDevice = AudioHW.defaultOutputDevice()
        listener = AudioHW.listen(AudioHW.system, AudioHW.address(kAudioHardwarePropertyDefaultOutputDevice)) { [weak self] in
            self?.outputChanged()
        }
    }

    public func stop() {
        listener?.remove()
        listener = nil
    }

    private func outputChanged() {
        let device = AudioHW.defaultOutputDevice()
        guard device != currentDevice else { return }
        currentDevice = device
        guard AudioHW.isBluetooth(device), let name = AudioHW.deviceName(device) else { return }
        if let lastAnnounced, lastAnnounced.name == name, Date().timeIntervalSince(lastAnnounced.date) < 60 {
            return
        }
        lastAnnounced = (name, Date())
        let symbol = HeadphoneSymbol.symbol(forDeviceName: name)
        onAlert?(.headphones(name: name, symbol: symbol))
        announceBattery(name: name, symbol: symbol, connectedAt: Date())
    }

    /// Reads the battery off the main thread and updates the alert while it's still up (it
    /// shows for 3 s). AirPods often report a level only once they're in your ears, so a miss
    /// just leaves "Connected".
    private func announceBattery(name: String, symbol: String, connectedAt: Date) {
        Task.detached(priority: .utility) {
            guard let data = Self.systemProfilerBluetooth(),
                  let level = BluetoothBattery.level(named: name, inSystemProfilerJSON: data)
            else { return }
            await MainActor.run { [weak self] in
                guard Date().timeIntervalSince(connectedAt) < 2.5 else { return }
                self?.onAlert?(.headphones(name: name, symbol: symbol, battery: level))
            }
        }
    }

    nonisolated private static func systemProfilerBluetooth() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json", "SPBluetoothDataType"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
