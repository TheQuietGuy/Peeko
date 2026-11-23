import Foundation

/// The tiles of the launcher grid, in order, each with its keyboard shortcut (⌃⌥ + key).
public enum LauncherItem: String, CaseIterable, Sendable, Identifiable {
    case nowPlaying
    case timer
    case stopwatch
    case calendar
    case reminders
    case clipboard
    case files
    case scratchpad
    case mirror
    case keepAwake
    case stats
    case weather
    case colors
    case countdowns
    case aiUsage

    public var id: String { rawValue }

    /// The short name shared by the launcher and the editable shortcut area.
    public var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .clipboard: "Clipboard"
        case .files: "Files"
        case .scratchpad: "Scratchpad"
        case .mirror: "Camera Mirror"
        case .keepAwake: "Keep Awake"
        case .stats: "Stats"
        case .weather: "Weather"
        case .colors: "Colour Picker"
        case .countdowns: "Countdowns"
        case .aiUsage: "AI Agent Usage"
        }
    }

    /// One word for the navigation bar, where the current view shows its name.
    public var shortTitle: String {
        switch self {
        case .nowPlaying: "Music"
        case .scratchpad: "Notes"
        case .mirror: "Mirror"
        case .keepAwake: "Awake"
        case .aiUsage: "AI"
        case .reminders: "To-dos"
        case .colors: "Colours"
        default: title
        }
    }

    /// The name on a grid tile: the full name unless it's too long for seven across.
    public var gridTitle: String {
        switch self {
        case .mirror: "Mirror"
        case .aiUsage: "AI Usage"
        case .colors: "Colours"
        default: title
        }
    }

    /// The feature a Home view belongs to, so the navigation bar can name where you are.
    public static func forTab(_ tab: HomeTab, stopwatch: Bool) -> LauncherItem? {
        switch tab {
        case .home, .launcher: nil
        case .tray: .files
        case .clipboard: .clipboard
        case .notes: .scratchpad
        case .mirror: .mirror
        case .timers: stopwatch ? .stopwatch : .timer
        case .calendar: .calendar
        case .reminders: .reminders
        case .stats: .stats
        case .weather: .weather
        case .colors: .colors
        case .countdowns: .countdowns
        case .aiUsage: .aiUsage
        }
    }

    /// The SF Symbol shared by the launcher and the editable shortcut area.
    public var symbolName: String {
        switch self {
        case .nowPlaying: "music.note"
        case .timer: "timer"
        case .stopwatch: "stopwatch"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .clipboard: "doc.on.clipboard"
        case .files: "tray.full"
        case .scratchpad: "note.text"
        case .mirror: "web.camera"
        case .keepAwake: "cup.and.saucer"
        case .stats: "gauge.with.dots.needle.33percent"
        case .weather: "cloud.sun"
        case .colors: "eyedropper.halffull"
        case .countdowns: "hourglass"
        case .aiUsage: "sparkles"
        }
    }

    /// The letter pressed with Control and Option. Chosen to stay clear of the window
    /// managers' usual Control-Option keys (arrows, C, D, E, F, G, T, U, I, J, K).
    public var key: Character {
        switch self {
        case .nowPlaying: "M"
        case .timer: "R"
        case .stopwatch: "S"
        case .calendar: "A"
        case .reminders: "O"
        case .clipboard: "B"
        case .files: "L"
        case .scratchpad: "N"
        case .mirror: "W"
        case .keepAwake: "Z"
        case .stats: "P"
        case .weather: "H"
        case .colors: "X"
        case .countdowns: "Y"
        case .aiUsage: "U"
        }
    }

    /// "⌃⌥M", as shown on the tile.
    public var shortcutLabel: String { "⌃⌥" + String(key) }
}
