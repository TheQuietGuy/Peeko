import Foundation

/// One picked colour as 8-bit sRGB, and the ways designers and developers paste it.
public struct PickedColor: Equatable, Hashable, Sendable {
    public var red: Int
    public var green: Int
    public var blue: Int

    public init(red: Int, green: Int, blue: Int) {
        self.red = min(max(red, 0), 255)
        self.green = min(max(green, 0), 255)
        self.blue = min(max(blue, 0), 255)
    }

    /// From 0…1 components, as AppKit gives them.
    public init(red: Double, green: Double, blue: Double) {
        self.init(red: Int((red * 255).rounded()), green: Int((green * 255).rounded()), blue: Int((blue * 255).rounded()))
    }

    /// "#1A2B3C" or "1a2b3c"; nil for anything else.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(red: value >> 16 & 0xFF, green: value >> 8 & 0xFF, blue: value & 0xFF)
    }

    public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
    public var rgb: String { "rgb(\(red), \(green), \(blue))" }

    public var hsl: String {
        let r = Double(red) / 255, g = Double(green) / 255, b = Double(blue) / 255
        let high = max(r, g, b), low = min(r, g, b), chroma = high - low
        let lightness = (high + low) / 2
        let saturation = chroma == 0 ? 0 : chroma / (1 - abs(2 * lightness - 1))
        var hue = 0.0
        if chroma > 0 {
            switch high {
            case r: hue = (g - b) / chroma
            case g: hue = (b - r) / chroma + 2
            default: hue = (r - g) / chroma + 4
            }
            hue = (hue * 60).truncatingRemainder(dividingBy: 360)
            if hue < 0 { hue += 360 }
        }
        return "hsl(\(Int(hue.rounded())), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%)"
    }

    public var swiftUI: String {
        func part(_ value: Int) -> String { String(format: "%.3f", Double(value) / 255) }
        return "Color(red: \(part(red)), green: \(part(green)), blue: \(part(blue)))"
    }

    /// True when black text reads better on it than white.
    public var isLight: Bool {
        (0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)) / 255 > 0.6
    }
}

/// A date to count down to: an exam, a deadline, a trip.
public struct Countdown: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var date: Date

    public init(id: UUID = UUID(), title: String, date: Date) {
        self.id = id
        self.title = title
        self.date = date
    }

    /// Whole calendar days from today to its day: 0 today, negative once it's passed.
    public func daysLeft(from now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// The big number and the word under it, e.g. ("12", "days"), ("Today", "").
    public func label(from now: Date, calendar: Calendar = .current) -> (value: String, caption: String) {
        let days = daysLeft(from: now, calendar: calendar)
        switch days {
        case 0: return (String(localized: "Today"), "")
        case 1: return ("1", String(localized: "day"))
        case 2...: return ("\(days)", String(localized: "days"))
        case -1: return ("1", String(localized: "day ago"))
        default: return ("\(-days)", String(localized: "days ago"))
        }
    }

    /// Soonest first, then the ones that have passed, most recent first.
    public static func ordered(_ items: [Countdown], now: Date, calendar: Calendar = .current) -> [Countdown] {
        let upcoming = items.filter { $0.daysLeft(from: now, calendar: calendar) >= 0 }.sorted { $0.date < $1.date }
        let past = items.filter { $0.daysLeft(from: now, calendar: calendar) < 0 }.sorted { $0.date > $1.date }
        return upcoming + past
    }
}
