import CoreLocation
import Foundation
import Observation

/// Where the Mac is, for Weather's "Use My Location". Asks macOS for permission the first time
/// it's needed, takes one reading (city-level accuracy is plenty), and names the place.
/// A reading is kept for an hour, so the 30-minute weather refresh doesn't wake Location Services.
@MainActor
@Observable
public final class LocationService: NSObject {
    public enum Failure: Error, Equatable, Sendable {
        /// Location Services is off, or Peeko isn't allowed in System Settings.
        case denied
        /// macOS couldn't work out where the Mac is right now.
        case unavailable
    }

    public private(set) var authorization: CLAuthorizationStatus

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var locationWaiters: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    @ObservationIgnored private var cached: (place: WeatherAPI.Place, at: Date)?

    static let reuseFor: TimeInterval = 60 * 60

    public override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// The current place, asking for permission if it hasn't been asked yet.
    public func currentPlace() async -> Result<WeatherAPI.Place, Failure> {
        if let cached, Date().timeIntervalSince(cached.at) < Self.reuseFor { return .success(cached.place) }
        if authorization == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                manager.requestWhenInUseAuthorization()
            }
        }
        guard LocationRules.isAllowed(authorization) else { return .failure(.denied) }
        let coordinate = await withCheckedContinuation { continuation in
            locationWaiters.append(continuation)
            if locationWaiters.count == 1 { manager.requestLocation() }
        }
        guard let coordinate else { return .failure(.unavailable) }
        let name = await Self.placeName(for: coordinate)
        let place = WeatherAPI.Place(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
        cached = (place, Date())
        return .success(place)
    }

    /// "Uxbridge", from Apple's geocoder; "My Location" if it can't say.
    private static func placeName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        return LocationRules.name(locality: placemark?.locality, subLocality: placemark?.subLocality, area: placemark?.administrativeArea)
    }

    fileprivate func authorizationChanged(_ status: CLAuthorizationStatus) {
        authorization = status
        guard status != .notDetermined else { return }
        let waiters = authorizationWaiters
        authorizationWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    fileprivate func located(_ coordinate: CLLocationCoordinate2D?) {
        let waiters = locationWaiters
        locationWaiters.removeAll()
        waiters.forEach { $0.resume(returning: coordinate) }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorizationChanged(status) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in self.located(coordinate) }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in self.located(nil) }
    }
}

/// The decisions behind location, kept pure for tests.
public enum LocationRules {
    public static func isAllowed(_ status: CLAuthorizationStatus) -> Bool {
        // macOS reports "when in use" permission as always.
        status == .authorizedAlways
    }

    public static func name(locality: String?, subLocality: String?, area: String?) -> String {
        for candidate in [locality, subLocality, area] {
            if let candidate, !candidate.trimmingCharacters(in: .whitespaces).isEmpty { return candidate }
        }
        return String(localized: "My Location")
    }
}
