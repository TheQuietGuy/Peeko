import Foundation

/// The widgets Home can show, which you switch on and order in Settings › Home & Widgets.
/// Home shows the first three that have something to show, side by side.
public enum HomeWidget: String, CaseIterable, Sendable, Codable, Identifiable {
    /// What's playing or happening: music, a call, Stats and AI usage while they're live.
    case live
    /// The date, the weather and your next event.
    case today
    case weather
    case timer
    case shortcuts
    case aiUsage

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .live: String(localized: "Now Playing & Live")
        case .today: String(localized: "Today")
        case .weather: String(localized: "Weather")
        case .timer: String(localized: "Timer")
        case .shortcuts: String(localized: "Shortcuts")
        case .aiUsage: String(localized: "AI Agent Usage")
        }
    }

    public var detail: String {
        switch self {
        case .live: String(localized: "Music, calls and anything live")
        case .today: String(localized: "Date, weather and your next event")
        case .weather: String(localized: "Now and the next few hours")
        case .timer: String(localized: "Quick timers and Focus")
        case .shortcuts: String(localized: "Your favourite Shortcuts")
        case .aiUsage: String(localized: "Coding assistant limits")
        }
    }

    public var symbolName: String {
        switch self {
        case .live: "play.circle.fill"
        case .today: "calendar"
        case .weather: "cloud.sun.fill"
        case .timer: "timer"
        case .shortcuts: "square.stack.3d.up.fill"
        case .aiUsage: "sparkles"
        }
    }

    /// The original Home, with Weather after it so it only appears when there's room or you move it up.
    public static let defaultOrder: [HomeWidget] = [.live, .today, .timer, .shortcuts, .aiUsage, .weather]
}

/// One column of Home.
public enum HomeSlot: Equatable, Sendable {
    case widget(HomeWidget)
    /// Timer and Shortcuts share a column when there isn't a column left for each.
    case timerAndShortcuts
}

public enum HomeLayout {
    public static let maximumColumns = 3

    /// The columns Home shows: the switched-on widgets in your order, skipping any with nothing
    /// to show. When more than three qualify, Timer and Shortcuts share a column (if they can)
    /// before anything is dropped.
    public static func arrange(order: [HomeWidget], available: Set<HomeWidget>, timerCanShare: Bool) -> [HomeSlot] {
        var slots = order.filter(available.contains).map(HomeSlot.widget)
        if slots.count > maximumColumns, timerCanShare,
           let timer = slots.firstIndex(of: .widget(.timer)), let shortcuts = slots.firstIndex(of: .widget(.shortcuts)) {
            let first = min(timer, shortcuts)
            slots.remove(at: max(timer, shortcuts))
            slots[first] = .timerAndShortcuts
        }
        return Array(slots.prefix(maximumColumns))
    }

    /// A saved order made whole: unknown names dropped, repeats removed. Widgets added in a
    /// later version are not switched on by themselves.
    public static func normalized(_ rawValues: [String]) -> [HomeWidget] {
        var seen = Set<HomeWidget>()
        return rawValues.compactMap(HomeWidget.init(rawValue:)).filter { seen.insert($0).inserted }
    }
}
