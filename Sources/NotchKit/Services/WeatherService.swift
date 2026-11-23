import Foundation
import Observation

/// Weather for one city, refreshed every 30 minutes while Weather is on, and again when the
/// Weather view opens if the reading is more than 10 minutes old.
@MainActor
@Observable
public final class WeatherService {
    public enum Status: Equatable, Sendable {
        case off
        case loading
        case ready
        /// The city wasn't found.
        case unknownCity
        /// Offline, or Open-Meteo didn't answer; the last reading (if any) stays.
        case unavailable
        /// "Use My Location" is on but Perch isn't allowed to know where the Mac is.
        case locationDenied
        /// macOS couldn't find the Mac's location right now.
        case locationUnavailable
    }

    /// Where the forecast is for: a typed city, or wherever the Mac is.
    public enum Source: Equatable, Sendable {
        case city(String)
        case currentLocation
    }

    /// Finds the Mac's location; set by the model to `LocationService.currentPlace`.
    @ObservationIgnored public var locate: @MainActor () async -> Result<WeatherAPI.Place, LocationService.Failure> = { .failure(.unavailable) }

    public private(set) var forecast: WeatherForecast?
    public private(set) var status: Status = .off
    public private(set) var updatedAt: Date?
    public var current: WeatherNow? { forecast?.now }

    @ObservationIgnored private var source: Source?
    @ObservationIgnored private var place: WeatherAPI.Place?
    @ObservationIgnored private var refresh: Task<Void, Never>?
    @ObservationIgnored private let session: URLSession

    static let interval: Duration = .seconds(30 * 60)
    static let staleAfter: TimeInterval = 10 * 60

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Call when the settings change. Off, or an empty city without location, clears everything.
    public func update(enabled: Bool, city newCity: String, useLocation: Bool = false) {
        let wanted = WeatherService.source(enabled: enabled, city: newCity, useLocation: useLocation)
        guard wanted != source else { return }
        source = wanted
        place = nil
        forecast = nil
        updatedAt = nil
        restart(delay: wanted == .currentLocation ? .zero : .milliseconds(800))
    }

    /// What to fetch for, from the settings.
    nonisolated static func source(enabled: Bool, city: String, useLocation: Bool) -> Source? {
        guard enabled else { return nil }
        if useLocation { return .currentLocation }
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : .city(trimmed)
    }

    /// The Weather view opened: fetch again if the reading is getting old.
    public func refreshIfStale() {
        guard source != nil, status != .loading else { return }
        if let updatedAt, Date().timeIntervalSince(updatedAt) < Self.staleAfter { return }
        restart(delay: .zero)
    }

    private func restart(delay: Duration) {
        refresh?.cancel()
        refresh = nil
        guard let source else {
            status = .off
            return
        }
        status = .loading
        let fahrenheit = Locale.current.measurementSystem == .us
        refresh = Task { [weak self, session] in
            // A short wait, so typing a city doesn't send a request per letter.
            try? await Task.sleep(for: delay)
            while !Task.isCancelled {
                guard let self else { return }
                await self.fetch(source: source, fahrenheit: fahrenheit, session: session)
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    private func fetch(source: Source, fahrenheit: Bool, session: URLSession) async {
        switch source {
        case .currentLocation:
            // Asked every round: the Mac may have moved (the service reuses a reading for an hour).
            switch await locate() {
            case .success(let found): place = found
            case .failure(let failure):
                if self.source == source { status = failure == .denied ? .locationDenied : .locationUnavailable }
                return
            }
        case .city(let city) where place == nil:
            guard let url = WeatherAPI.geocodeURL(city: city), let (data, _) = try? await session.data(from: url) else {
                if self.source == source { status = .unavailable }
                return
            }
            guard let found = WeatherAPI.place(from: data) else {
                if self.source == source { status = .unknownCity }
                return
            }
            place = found
        case .city:
            break
        }
        guard let place, let url = WeatherAPI.forecastURL(place, fahrenheit: fahrenheit),
              let (data, _) = try? await session.data(from: url),
              let forecast = WeatherAPI.forecast(from: data, city: place.name) else {
            if self.source == source { status = .unavailable }
            return
        }
        guard self.source == source else { return }
        self.forecast = forecast
        updatedAt = Date()
        status = .ready
    }
}
