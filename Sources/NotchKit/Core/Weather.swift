import Foundation

/// The weather glance in Home, from Open-Meteo (free, no account or key). Only the city you
/// typed, then its coordinates, are sent.
public struct WeatherNow: Equatable, Sendable {
    public var temperature: Double
    public var code: Int
    public var isDay: Bool
    public var city: String

    public init(temperature: Double, code: Int, isDay: Bool, city: String) {
        self.temperature = temperature
        self.code = code
        self.isDay = isDay
        self.city = city
    }

    /// "14°", rounded, in whichever unit was asked for.
    public var temperatureLabel: String { "\(Int(temperature.rounded()))°" }

    /// SF Symbol for a WMO weather code (what Open-Meteo reports).
    public var symbolName: String { WeatherCodes.symbol(for: code, isDay: isDay) }
    public var summary: String { WeatherCodes.summary(for: code) }
}

public enum WeatherCodes {
    public static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    public static func summary(for code: Int) -> String {
        switch code {
        case 0: String(localized: "Clear")
        case 1, 2: String(localized: "Partly cloudy")
        case 3: String(localized: "Cloudy")
        case 45, 48: String(localized: "Fog")
        case 51...57: String(localized: "Drizzle")
        case 61...67, 80...82: String(localized: "Rain")
        case 71...77, 85, 86: String(localized: "Snow")
        case 95...99: String(localized: "Thunderstorm")
        default: String(localized: "Cloudy")
        }
    }
}

public enum WeatherAPI {
    public struct Place: Equatable, Sendable {
        public var name: String
        public var latitude: Double
        public var longitude: Double
    }

    public static func geocodeURL(city: String) -> URL? {
        var parts = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        parts?.queryItems = [.init(name: "name", value: city), .init(name: "count", value: "1")]
        return parts?.url
    }

    public static func forecastURL(_ place: Place, fahrenheit: Bool) -> URL? {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        parts?.queryItems = [
            .init(name: "latitude", value: String(place.latitude)),
            .init(name: "longitude", value: String(place.longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
            .init(name: "wind_speed_unit", value: fahrenheit ? "mph" : "kmh"),
        ]
        return parts?.url
    }

    /// The whole forecast: now, the next hours and the week. `now` picks which hours are still
    /// to come; the times in the answer are local to the place, as Open-Meteo sends them.
    public static func forecast(from data: Data, city: String, now: Date = Date()) -> WeatherForecast? {
        guard let current = self.now(from: data, city: city),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let currentBlock = root["current"] as? [String: Any] ?? [:]
        let offset = (root["utc_offset_seconds"] as? NSNumber)?.intValue ?? 0
        let zone = TimeZone(secondsFromGMT: offset) ?? .current
        func doubles(_ block: [String: Any], _ key: String) -> [Double?] { (block[key] as? [Any] ?? []).map { ($0 as? NSNumber)?.doubleValue } }
        func strings(_ block: [String: Any], _ key: String) -> [String] { block[key] as? [String] ?? [] }

        var hours: [WeatherForecast.Hour] = []
        if let hourly = root["hourly"] as? [String: Any] {
            let times = strings(hourly, "time"), temps = doubles(hourly, "temperature_2m")
            let codes = doubles(hourly, "weather_code"), rain = doubles(hourly, "precipitation_probability")
            let day = doubles(hourly, "is_day")
            for index in times.indices {
                guard let date = localDate(times[index], zone: zone, hasTime: true),
                      date > now.addingTimeInterval(-3600),
                      let temperature = temps[safe: index] ?? nil, let code = codes[safe: index] ?? nil else { continue }
                hours.append(.init(time: date, temperature: temperature, code: Int(code),
                                   rainChance: (rain[safe: index] ?? nil).map { Int($0) }, isDay: ((day[safe: index] ?? nil) ?? 1) != 0))
                if hours.count == 12 { break }
            }
        }
        var days: [WeatherForecast.Day] = []
        if let daily = root["daily"] as? [String: Any] {
            let times = strings(daily, "time"), highs = doubles(daily, "temperature_2m_max"), lows = doubles(daily, "temperature_2m_min")
            let codes = doubles(daily, "weather_code"), rain = doubles(daily, "precipitation_probability_max")
            let sunrises = strings(daily, "sunrise"), sunsets = strings(daily, "sunset")
            for index in times.indices {
                guard let date = localDate(times[index], zone: zone, hasTime: false),
                      let high = highs[safe: index] ?? nil, let low = lows[safe: index] ?? nil, let code = codes[safe: index] ?? nil else { continue }
                days.append(.init(date: date, high: high, low: low, code: Int(code),
                                  rainChance: (rain[safe: index] ?? nil).map { Int($0) },
                                  sunrise: sunrises[safe: index].flatMap { localDate($0, zone: zone, hasTime: true) },
                                  sunset: sunsets[safe: index].flatMap { localDate($0, zone: zone, hasTime: true) }))
            }
        }
        return WeatherForecast(
            now: current,
            feelsLike: (currentBlock["apparent_temperature"] as? NSNumber)?.doubleValue,
            humidity: (currentBlock["relative_humidity_2m"] as? NSNumber)?.intValue,
            wind: (currentBlock["wind_speed_10m"] as? NSNumber)?.doubleValue,
            hours: hours, days: days, timeZone: zone
        )
    }

    /// "2026-11-22T14:00" or "2026-11-22", in the place's time zone.
    static func localDate(_ text: String, zone: TimeZone, hasTime: Bool) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = hasTime ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    public static func place(from data: Data) -> Place? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (root["results"] as? [[String: Any]])?.first,
              let name = first["name"] as? String,
              let latitude = first["latitude"] as? Double,
              let longitude = first["longitude"] as? Double
        else { return nil }
        return Place(name: name, latitude: latitude, longitude: longitude)
    }

    public static func now(from data: Data, city: String) -> WeatherNow? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = root["current"] as? [String: Any],
              let temperature = (current["temperature_2m"] as? NSNumber)?.doubleValue,
              let code = (current["weather_code"] as? NSNumber)?.intValue
        else { return nil }
        let isDay = (current["is_day"] as? NSNumber)?.intValue != 0
        return WeatherNow(temperature: temperature, code: code, isDay: isDay, city: city)
    }
}

/// Everything the Weather view shows.
public struct WeatherForecast: Equatable, Sendable {
    public struct Hour: Equatable, Sendable, Identifiable {
        public var time: Date
        public var temperature: Double
        public var code: Int
        public var rainChance: Int?
        public var isDay: Bool
        public var id: Date { time }
        public var symbolName: String { WeatherCodes.symbol(for: code, isDay: isDay) }
    }

    public struct Day: Equatable, Sendable, Identifiable {
        public var date: Date
        public var high: Double
        public var low: Double
        public var code: Int
        public var rainChance: Int?
        public var sunrise: Date?
        public var sunset: Date?
        public var id: Date { date }
        public var symbolName: String { WeatherCodes.symbol(for: code, isDay: true) }
    }

    public var now: WeatherNow
    public var feelsLike: Double?
    public var humidity: Int?
    public var wind: Double?
    public var hours: [Hour]
    public var days: [Day]
    /// The place's time zone, so hours read as they do there.
    public var timeZone: TimeZone

    public var today: Day? { days.first }

    /// Where today's low and high sit on the week's range, 0…1, for the bars in the week list.
    public func range(of day: Day) -> ClosedRange<Double> {
        let low = days.map(\.low).min() ?? day.low
        let high = days.map(\.high).max() ?? day.high
        let span = max(high - low, 0.1)
        return ((day.low - low) / span)...((day.high - low) / span)
    }

    /// "Rain likely around 15:00": the first coming hour with a 50 % chance or more.
    public var rainAlert: Hour? {
        hours.first { ($0.rainChance ?? 0) >= 50 }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
