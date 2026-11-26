import SwiftUI

// Stats: memory and CPU beside the camera, and a panel with memory, CPU, disk and network,
// styled like the small gauges in Activity Monitor and Control Center.

extension StatsMath.Level {
    var tint: Color {
        switch self {
        case .normal: NotchColor.green
        case .busy: NotchColor.yellow
        case .high: NotchColor.red
        }
    }
}

/// One side of the compact notch: a tiny caption over its value, like a watch complication.
struct StatsCompactValue: View {
    let caption: LocalizedStringKey
    let share: Double?
    /// Colour override (memory follows pressure, not percentage).
    var level: StatsMath.Level?
    let fontSize: CGFloat
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(caption)
                .font(.system(size: max(7, fontSize * 0.55), weight: .bold))
                .kerning(0.3)
                .foregroundStyle(NotchColor.secondaryText)
            Text(share.map(StatsMath.percent) ?? "–")
                .font(.system(size: fontSize * 0.9, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(share.map { (level ?? StatsMath.level($0)).tint } ?? NotchColor.secondaryText)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// Everything about how the Mac is doing, in two rows: CPU, memory, GPU and network on top;
/// battery, disk, the system and the busiest apps below. Opens like Files, from its shortcut
/// beside Home or the grid; the switch at the top puts memory and CPU beside the camera.
struct StatsPanelBody: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let stats = model.stats
        let snapshot = stats.snapshot
        let details = stats.details
        let ready = stats.hasReading
        VStack(spacing: 8 * s) {
            StatsHeader(model: model, details: details)
                .frame(height: 22 * s)
            HStack(spacing: 8 * s) {
                CPUCard(snapshot: snapshot, details: details, history: stats.cpuHistory, ready: ready)
                MemoryCard(snapshot: snapshot, details: details)
                GPUCard(details: details, history: stats.gpuHistory)
                NetworkCard(snapshot: snapshot, details: details, down: stats.networkInHistory, up: stats.networkOutHistory, ready: ready)
            }
            HStack(spacing: 8 * s) {
                BatteryCard(battery: details.battery)
                DiskCard(snapshot: snapshot)
                SystemCard(details: details)
                TopAppsCard(processes: details.topProcesses)
            }
        }
        .padding(.bottom, 2 * s)
    }
}

/// The switch for the notch readout, and a one-line summary.
private struct StatsHeader: View {
    let model: IslandModel
    let details: SystemDetails
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 8 * s) {
            let on = model.settings.statsEnabled
            Button { model.settings.statsEnabled.toggle() } label: {
                Label("Memory and CPU beside the camera", systemImage: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11 * s, weight: .semibold))
                    .foregroundStyle(on ? NotchColor.green : NotchColor.secondaryText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityAddTraits(on ? .isSelected : [])
            Spacer(minLength: 6 * s)
            Label(StatsMath.thermalLabel(details.thermal), systemImage: details.thermal >= 2 ? "thermometer.high" : "thermometer.medium")
                .foregroundStyle(details.thermal >= 2 ? NotchColor.red : (details.thermal == 1 ? NotchColor.yellow : NotchColor.secondaryText))
            Label("Up \(StatsMath.duration(details.uptime))", systemImage: "clock")
                .foregroundStyle(NotchColor.secondaryText)
        }
        .font(.system(size: 10.5 * s, weight: .semibold))
        .monospacedDigit()
        .lineLimit(1)
    }
}

private struct CPUCard: View {
    let snapshot: SystemSnapshot
    let details: SystemDetails
    let history: [Double]
    let ready: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        StatsCard(title: "CPU", symbol: "cpu") {
            HStack(alignment: .firstTextBaseline, spacing: 6 * s) {
                BigValue(text: ready ? StatsMath.percent(snapshot.cpu) : "–", tint: ready ? StatsMath.level(snapshot.cpu).tint : .white)
                Text(ready ? "user \(StatsMath.percent(details.cpuUser)) · sys \(StatsMath.percent(details.cpuSystem))" : "")
                    .detailStyle(s)
            }
            Sparkline(values: history, tint: StatsMath.level(snapshot.cpu).tint)
                .frame(height: 22 * s)
            CoreBars(loads: details.coreLoads)
                .frame(height: 12 * s)
        }
        .help(details.loadAverage.isEmpty ? "" : "Load average " + details.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " · "))
    }
}

private struct MemoryCard: View {
    let snapshot: SystemSnapshot
    let details: SystemDetails
    @Environment(\.notchScale) private var s

    var body: some View {
        let known = snapshot.memoryTotal > 0
        StatsCard(title: "Memory", symbol: "memorychip") {
            BigValue(text: known ? StatsMath.percent(snapshot.memory) : "–", tint: snapshot.memoryPressure.tint)
            Text(known ? "\(StatsMath.bytes(Int64(snapshot.memoryUsed))) of \(StatsMath.bytes(Int64(snapshot.memoryTotal)))" : "")
                .detailStyle(s)
            Spacer(minLength: 2 * s)
            MemoryBar(details: details, total: snapshot.memoryTotal)
                .frame(height: 5 * s)
            Text(details.swapUsed > 0 ? "Swap \(StatsMath.bytes(Int64(details.swapUsed)))" : "Pressure \(pressureLabel)")
                .detailStyle(s)
        }
        .help("App \(StatsMath.bytes(Int64(details.memoryApp))) · Wired \(StatsMath.bytes(Int64(details.memoryWired))) · Compressed \(StatsMath.bytes(Int64(details.memoryCompressed)))")
    }

    private var pressureLabel: String {
        switch snapshot.memoryPressure {
        case .normal: String(localized: "normal")
        case .busy: String(localized: "rising")
        case .high: String(localized: "high")
        }
    }
}

private struct GPUCard: View {
    let details: SystemDetails
    let history: [Double]
    @Environment(\.notchScale) private var s

    var body: some View {
        StatsCard(title: "GPU", symbol: "square.stack.3d.up") {
            BigValue(text: details.gpu.map(StatsMath.percent) ?? "–", tint: details.gpu.map { StatsMath.level($0).tint } ?? .white)
            Spacer(minLength: 2 * s)
            Sparkline(values: history, tint: NotchColor.blue)
                .frame(height: 22 * s)
        }
    }
}

private struct NetworkCard: View {
    let snapshot: SystemSnapshot
    let details: SystemDetails
    let down: [Double]
    let up: [Double]
    let ready: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        StatsCard(title: "Network", symbol: "network") {
            rate("arrow.down", ready ? StatsMath.rate(snapshot.networkIn) : "–", tint: NotchColor.blue)
            rate("arrow.up", ready ? StatsMath.rate(snapshot.networkOut) : "–", tint: NotchColor.orange)
            ZStack {
                Sparkline(values: down, tint: NotchColor.blue, normalize: true)
                Sparkline(values: up, tint: NotchColor.orange, normalize: true, filled: false)
            }
            .frame(height: 16 * s)
            Text(details.localAddress ?? "Offline")
                .detailStyle(s)
                .textSelection(.enabled)
        }
    }

    private func rate(_ symbol: String, _ text: String, tint: Color) -> some View {
        HStack(spacing: 4 * s) {
            Image(systemName: symbol)
                .font(.system(size: 10 * s, weight: .bold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 13 * s, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct BatteryCard: View {
    let battery: BatteryInfo?
    @Environment(\.notchScale) private var s

    var body: some View {
        StatsCard(title: "Battery", symbol: battery?.isCharging == true ? "battery.100percent.bolt" : "battery.75percent") {
            if let battery {
                BigValue(text: "\(battery.level)%", tint: battery.level <= 20 && !battery.onPower ? NotchColor.red : NotchColor.green)
                Text(BatteryText.state(battery)).detailStyle(s)
                Text(BatteryText.health(battery)).detailStyle(s)
                Text(BatteryText.power(battery)).detailStyle(s)
            } else {
                BigValue(text: "–", tint: .white)
                Text("No battery on this Mac").detailStyle(s)
            }
        }
    }
}

/// Battery lines, kept apart from the view so they're easy to read and test.
enum BatteryText {
    static func state(_ battery: BatteryInfo) -> String {
        let time = battery.minutesRemaining.map { StatsMath.duration(TimeInterval($0 * 60)) }
        if battery.isCharging { return time.map { String(localized: "Charging · \($0) to full") } ?? String(localized: "Charging") }
        if battery.onPower { return String(localized: "On power") }
        return time.map { String(localized: "\($0) left") } ?? String(localized: "On battery")
    }

    static func health(_ battery: BatteryInfo) -> String {
        var parts: [String] = []
        if let health = battery.health { parts.append(String(localized: "Health \(StatsMath.percent(health))")) }
        if let cycles = battery.cycleCount { parts.append(String(localized: "\(cycles) cycles")) }
        return parts.joined(separator: " · ")
    }

    static func power(_ battery: BatteryInfo) -> String {
        var parts: [String] = []
        if let watts = battery.watts, abs(watts) >= 0.1 { parts.append(String(format: "%.1f W", abs(watts))) }
        if let temperature = battery.temperature { parts.append(String(format: "%.0f°C", temperature)) }
        if let adapter = battery.adapterWatts { parts.append(String(localized: "\(adapter) W charger")) }
        return parts.joined(separator: " · ")
    }
}

private struct DiskCard: View {
    let snapshot: SystemSnapshot
    @Environment(\.notchScale) private var s

    var body: some View {
        let known = snapshot.diskTotal > 0
        StatsCard(title: "Disk", symbol: "internaldrive") {
            BigValue(text: known ? StatsMath.bytes(snapshot.diskFree) : "–", tint: .white)
            Text(known ? "free of \(StatsMath.bytes(snapshot.diskTotal))" : "").detailStyle(s)
            Spacer(minLength: 2 * s)
            StatsBar(share: known ? snapshot.disk : nil)
                .frame(height: 5 * s)
        }
    }
}

private struct SystemCard: View {
    let details: SystemDetails
    @Environment(\.notchScale) private var s

    var body: some View {
        StatsCard(title: "Load", symbol: "gauge.with.dots.needle.67percent") {
            BigValue(text: details.loadAverage.first.map { String(format: "%.2f", $0) } ?? "–", tint: .white)
            Text(details.loadAverage.count == 3 ? String(format: "5m %.2f · 15m %.2f", details.loadAverage[1], details.loadAverage[2]) : "")
                .detailStyle(s)
            Spacer(minLength: 2 * s)
            Text("\(ProcessInfo.processInfo.activeProcessorCount) cores").detailStyle(s)
        }
        .help("How many tasks were waiting for a core, on average. Below the number of cores is relaxed.")
    }
}

private struct TopAppsCard: View {
    let processes: [ProcessLoad]
    @Environment(\.notchScale) private var s

    var body: some View {
        StatsCard(title: "Busiest", symbol: "flame") {
            if processes.isEmpty {
                Text("Measuring…").detailStyle(s)
            }
            ForEach(processes) { process in
                HStack(spacing: 4 * s) {
                    Text(process.name)
                        .font(.system(size: 10.5 * s, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4 * s)
                    Text("\(Int((process.cpu * 100).rounded()))%")
                        .font(.system(size: 10.5 * s, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(process.cpu >= 0.8 ? NotchColor.orange : NotchColor.secondaryText)
                }
            }
        }
        .help("CPU per app, as Activity Monitor shows it: 100% is one full core.")
    }
}

/// A Stats tile. Soft and rounded normally; in Brutal, a white outline on a pale offset plate.
private struct StatsCard<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: () -> Content
    @Environment(\.notchScale) private var s
    @Environment(\.brutal) private var brutal

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: (brutal ? 8 : 14) * s, style: .continuous)
        VStack(alignment: .leading, spacing: 3 * s) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10 * s, weight: brutal ? .bold : .semibold))
                .foregroundStyle(brutal ? BrutalPalette.edge : NotchColor.secondaryText)
                .lineLimit(1)
            content()
            Spacer(minLength: 0)
        }
        .padding(8 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Opaque in Brutal, so the hard shadow behind doesn't show through.
        .background(shape.fill(brutal ? Color(white: 0.09) : Color.white.opacity(0.07)))
        .overlay { if brutal { shape.strokeBorder(BrutalPalette.edge.opacity(0.9), lineWidth: BrutalPalette.edgeWidth) } }
        .background { if brutal { shape.fill(BrutalPalette.shadow).offset(x: 3 * s, y: 3 * s) } }
        .accessibilityElement(children: .combine)
    }
}

private struct BigValue: View {
    let text: String
    let tint: Color
    @Environment(\.notchScale) private var s

    var body: some View {
        Text(text)
            .font(.system(size: 20 * s, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }
}

private extension Text {
    func detailStyle(_ s: CGFloat) -> some View {
        font(.system(size: 9.5 * s, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(NotchColor.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

/// A small line chart of recent readings, newest on the right.
struct Sparkline: View {
    let values: [Double]
    let tint: Color
    /// Scale to the largest value shown (network) instead of 0…1 (shares).
    var normalize = false
    var filled = true

    var body: some View {
        Canvas { context, size in
            let points = SparklineMath.points(values, in: size, normalize: normalize)
            guard points.count > 1 else { return }
            var line = Path()
            line.addLines(points)
            if filled {
                var area = line
                area.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
                area.addLine(to: CGPoint(x: points[0].x, y: size.height))
                area.closeSubpath()
                context.fill(area, with: .color(tint.opacity(0.22)))
            }
            context.stroke(line, with: .color(tint), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// One thin bar per core, like Activity Monitor's CPU History window.
private struct CoreBars: View {
    let loads: [Double]

    var body: some View {
        GeometryReader { geometry in
            let count = max(loads.count, 1)
            let gap: CGFloat = 1.5
            let width = max(1, (geometry.size.width - gap * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(loads.enumerated()), id: \.offset) { _, load in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.12))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(StatsMath.level(load).tint)
                            .frame(height: max(1, geometry.size.height * load))
                    }
                    .frame(width: width)
                }
            }
        }
        .animation(.smooth(duration: 0.4), value: loads)
        .accessibilityHidden(true)
    }
}

/// App, wired and compressed memory as one segmented bar.
private struct MemoryBar: View {
    let details: SystemDetails
    let total: UInt64

    var body: some View {
        GeometryReader { geometry in
            let whole = Double(max(total, 1))
            let parts: [(UInt64, Color)] = [(details.memoryApp, NotchColor.blue), (details.memoryWired, NotchColor.orange), (details.memoryCompressed, NotchColor.yellow)]
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                HStack(spacing: 0) {
                    ForEach(0..<parts.count, id: \.self) { index in
                        Rectangle()
                            .fill(parts[index].1)
                            .frame(width: geometry.size.width * min(1, Double(parts[index].0) / whole))
                    }
                }
                .clipShape(Capsule())
            }
        }
        .accessibilityHidden(true)
    }
}

/// A slim bar that fills and changes colour with the load.
struct StatsBar: View {
    let share: Double?
    var level: StatsMath.Level?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                if let share {
                    Capsule()
                        .fill((level ?? StatsMath.level(share)).tint)
                        .frame(width: max(geometry.size.height, geometry.size.width * share))
                }
            }
        }
        .animation(.smooth(duration: 0.5), value: share)
        .accessibilityHidden(true)
    }
}

/// The Stats widget in the elongated Home: three bars in a column.
struct StatsWidget: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let snapshot = model.stats.snapshot
        let ready = model.stats.hasReading
        Button { model.showTab(.stats) } label: {
            VStack(alignment: .leading, spacing: 8 * s) {
                row("Memory", value: snapshot.memoryTotal > 0 ? StatsMath.percent(snapshot.memory) : "–", share: snapshot.memoryTotal > 0 ? snapshot.memory : nil, level: snapshot.memoryPressure)
                row("CPU", value: ready ? StatsMath.percent(snapshot.cpu) : "–", share: ready ? snapshot.cpu : nil)
                HStack(spacing: 10 * s) {
                    Label(ready ? StatsMath.rate(snapshot.networkIn) : "–", systemImage: "arrow.down")
                    Label(ready ? StatsMath.rate(snapshot.networkOut) : "–", systemImage: "arrow.up")
                }
                .font(.system(size: 10.5 * s, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(NotchColor.secondaryText)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .help("Open Stats")
    }

    private func row(_ title: LocalizedStringKey, value: String, share: Double?, level: StatsMath.Level? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            HStack {
                Text(title)
                    .font(.system(size: 11 * s, weight: .semibold))
                    .foregroundStyle(NotchColor.secondaryText)
                Spacer(minLength: 6 * s)
                Text(value)
                    .font(.system(size: 13 * s, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            StatsBar(share: share, level: level)
                .frame(height: 4 * s)
        }
    }
}
