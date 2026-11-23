import Foundation
import Observation

/// Colours you picked and dates you count down to, saved on this Mac. No account, no permission.
@MainActor
@Observable
public final class PicksStore {
    /// Newest first.
    public private(set) var colors: [PickedColor] {
        didSet { defaults.set(colors.map(\.hex), forKey: Self.colorsKey) }
    }

    public private(set) var countdowns: [Countdown] {
        didSet { defaults.set(try? JSONEncoder().encode(countdowns), forKey: Self.countdownsKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private static let colorsKey = "picks.colors"
    private static let countdownsKey = "picks.countdowns"
    /// Two rows' worth of swatches.
    static let colorCapacity = 14
    static let countdownCapacity = 20

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        colors = (defaults.stringArray(forKey: Self.colorsKey) ?? []).compactMap(PickedColor.init(hex:))
        countdowns = defaults.data(forKey: Self.countdownsKey).flatMap { try? JSONDecoder().decode([Countdown].self, from: $0) } ?? []
    }

    /// Puts it first; picking a colour you already have moves it to the front.
    public func add(_ color: PickedColor) {
        colors = Array(([color] + colors.filter { $0 != color }).prefix(Self.colorCapacity))
    }

    public func remove(_ color: PickedColor) {
        colors.removeAll { $0 == color }
    }

    public func clearColors() {
        colors = []
    }

    public func addCountdown(_ title: String, date: Date) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        countdowns = Array(([Countdown(title: String(trimmed.prefix(60)), date: date)] + countdowns).prefix(Self.countdownCapacity))
    }

    public func removeCountdown(_ id: UUID) {
        countdowns.removeAll { $0.id == id }
    }
}
