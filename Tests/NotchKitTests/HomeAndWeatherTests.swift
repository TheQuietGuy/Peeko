import AppKit
import Testing
@testable import NotchKit

@Suite("Home layout")
struct HomeLayoutTests {
    @Test func followsYourOrderAndSkipsEmptyWidgets() {
        let slots = HomeLayout.arrange(order: [.weather, .timer, .today, .live], available: [.weather, .timer, .today], timerCanShare: true)
        #expect(slots == [.widget(.weather), .widget(.timer), .widget(.today)], "your order; nothing live, so no live card")
    }

    @Test func atMostThreeColumns() {
        let slots = HomeLayout.arrange(order: HomeWidget.defaultOrder, available: Set(HomeWidget.allCases), timerCanShare: false)
        #expect(slots == [.widget(.live), .widget(.today), .widget(.timer)])
    }

    @Test func timerAndShortcutsShareRatherThanDropSomething() {
        let order: [HomeWidget] = [.live, .today, .timer, .shortcuts]
        let shared = HomeLayout.arrange(order: order, available: Set(order), timerCanShare: true)
        #expect(shared == [.widget(.live), .widget(.today), .timerAndShortcuts])
        let running = HomeLayout.arrange(order: order, available: Set(order), timerCanShare: false)
        #expect(running == [.widget(.live), .widget(.today), .widget(.timer)], "a running clock needs its column")
        let fits = HomeLayout.arrange(order: [.timer, .shortcuts], available: [.timer, .shortcuts], timerCanShare: true)
        #expect(fits == [.widget(.timer), .widget(.shortcuts)], "no need to share when there's room")
    }

    @Test func savedOrderIsCleanedUp() {
        #expect(HomeLayout.normalized(["weather", "nope", "weather", "today"]) == [.weather, .today])
        #expect(HomeWidget.defaultOrder.first == .live && HomeWidget.defaultOrder.last == .weather)
    }

    @MainActor @Test func settingsToggleReorderAndRemember() {
        let defaults = UserDefaults(suiteName: "home-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.homeWidgets == HomeWidget.defaultOrder)
        settings.moveHomeWidget(.weather, by: -1)
        #expect(settings.homeWidgets.suffix(2) == [.weather, .aiUsage])
        settings.moveHomeWidget(.live, by: -1)
        #expect(settings.homeWidgets.first == .live, "can't move past the start")
        settings.setHomeWidget(.today, on: false)
        #expect(!settings.homeWidgets.contains(.today))
        settings.setHomeWidget(.today, on: true)
        #expect(settings.homeWidgets.last == .today, "switched back on at the end")
        let reopened = SettingsStore(defaults: defaults)
        #expect(reopened.homeWidgets == settings.homeWidgets)
        reopened.resetHomeWidgets()
        #expect(reopened.homeWidgets == HomeWidget.defaultOrder)
    }

    @MainActor @Test func homeShowsWhatYouChose() {
        let defaults = UserDefaults(suiteName: "home-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        model.settings.calendarEnabled = true
        model.settings.timerEnabled = true
        #expect(HomeSection.sections(for: model).map(\.id) == ["calendar", "timer"])
        model.settings.weatherEnabled = true
        model.settings.homeWidgets = [.weather, .timer]
        #expect(HomeSection.sections(for: model).map(\.id) == ["weather", "timer"], "Today switched off, Weather first")
    }
}

@Suite("Weather forecast")
struct WeatherForecastTests {
    /// A trimmed real Open-Meteo answer for London (UTC, so times read plainly).
    static let sample = Data("""
    {"utc_offset_seconds":0,
     "current":{"temperature_2m":9.4,"apparent_temperature":6.8,"relative_humidity_2m":81,"wind_speed_10m":19.1,"weather_code":3,"is_day":1},
     "hourly":{"time":["2026-11-22T12:00","2026-11-22T13:00","2026-11-22T14:00","2026-11-22T15:00"],
               "temperature_2m":[8.9,9.4,9.8,9.1],"weather_code":[3,3,61,63],"precipitation_probability":[10,15,55,80],"is_day":[1,1,1,0]},
     "daily":{"time":["2026-11-22","2026-11-23"],"weather_code":[61,1],"temperature_2m_max":[10.2,12.0],"temperature_2m_min":[5.1,4.0],
              "precipitation_probability_max":[80,5],"sunrise":["2026-11-22T07:28","2026-11-23T07:30"],"sunset":["2026-11-22T16:01","2026-11-23T16:00"]}}
    """.utf8)
    static let noon = ISO8601DateFormatter().date(from: "2026-11-22T13:20:00Z")!

    @Test func readsNowHoursAndWeek() throws {
        let forecast = try #require(WeatherAPI.forecast(from: Self.sample, city: "London", now: Self.noon))
        #expect(forecast.now.temperatureLabel == "9°" && forecast.now.summary == "Cloudy")
        #expect(forecast.feelsLike == 6.8 && forecast.humidity == 81 && forecast.wind == 19.1)
        #expect(forecast.hours.count == 3, "12:00 is over an hour ago; 13:00 is now")
        #expect(forecast.hours.first?.temperature == 9.4)
        #expect(forecast.hours.last?.isDay == false)
        #expect(forecast.days.count == 2 && forecast.today?.high == 10.2)
        #expect(forecast.today?.sunset == ISO8601DateFormatter().date(from: "2026-11-22T16:01:00Z"))
    }

    @Test func rainAlertAndWeekRange() throws {
        let forecast = try #require(WeatherAPI.forecast(from: Self.sample, city: "London", now: Self.noon))
        #expect(forecast.rainAlert?.temperature == 9.8, "the first hour at 50 % or more")
        let today = try #require(forecast.today)
        let range = forecast.range(of: today)
        #expect(abs(range.lowerBound - 1.1 / 8) < 0.0001 && abs(range.upperBound - 6.2 / 8) < 0.0001)
    }

    /// Two full days of hours and a week, for a day's own hours.
    static func week() -> Data {
        var times: [String] = [], temps: [Double] = [], codes: [Int] = [], rain: [Int] = [], day: [Int] = []
        for d in 22...23 { for h in 0..<24 {
            times.append(String(format: "2026-11-%02dT%02d:00", d, h)); temps.append(Double(h) / 2)
            codes.append(h > 12 ? 61 : 3); rain.append(h * 4); day.append(h >= 8 && h < 16 ? 1 : 0)
        } }
        let days = (22...28).map { String(format: "2026-11-%02d", $0) }
        let json: [String: Any] = [
            "utc_offset_seconds": 0,
            "current": ["temperature_2m": 9.4, "weather_code": 3, "is_day": 1, "uv_index": 1.4],
            "hourly": ["time": times, "temperature_2m": temps, "weather_code": codes, "precipitation_probability": rain, "is_day": day],
            "daily": ["time": days, "weather_code": Array(repeating: 3, count: 7), "temperature_2m_max": (0..<7).map { 10.0 + Double($0) },
                      "temperature_2m_min": Array(repeating: 4.0, count: 7), "precipitation_probability_max": Array(repeating: 20, count: 7),
                      "sunrise": days.map { $0 + "T07:30" }, "sunset": days.map { $0 + "T16:00" }, "uv_index_max": Array(repeating: 2.6, count: 7)],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    @Test func eachDayHasItsOwnHours() throws {
        let forecast = try #require(WeatherAPI.forecast(from: Self.week(), city: "London", now: Self.noon))
        #expect(forecast.uv == 1.4 && forecast.today?.uv == 2.6)
        let today = try #require(forecast.today)
        #expect(forecast.hours(for: today).count == 8)
        #expect(forecast.hours(for: today).first?.time == ISO8601DateFormatter().date(from: "2026-11-22T13:00:00Z"), "from now")
        let tomorrow = forecast.days[1]
        let hours = forecast.hours(for: tomorrow)
        #expect(hours.count == 8, "every three hours across the day")
        #expect(hours.map { Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: $0.time).hour } == [0, 3, 6, 9, 12, 15, 18, 21])
        #expect(forecast.hours(for: forecast.days[3]).isEmpty, "no hours that far out in this sample")
        #expect(forecast.rainAlert?.rainChance == 52, "the first hour at 50 % or more, within the next 12")
    }

    @Test func uvBands() {
        #expect(WeatherText.uv(1.4) == "UV 1 Low")
        #expect(WeatherText.uv(6.2) == "UV 6 High")
        #expect(WeatherText.uv(11) == "UV 11 Extreme")
    }

    @Test func labels() {
        #expect(WeatherText.rain(10) == "")
        #expect(WeatherText.rain(55) == "60%")
        #expect(WeatherText.rain(nil) == "")
        let utc = TimeZone(identifier: "UTC")!
        let date = ISO8601DateFormatter().date(from: "2026-11-22T14:00:00Z")!
        #expect(WeatherText.hour(date, zone: utc, locale: Locale(identifier: "en_GB")) == "14")
        #expect(WeatherText.weekday(date, zone: utc, locale: Locale(identifier: "en_GB")) == "Sun")
        #expect(WeatherText.wind(19.1, locale: Locale(identifier: "en_GB")) == "19 km/h")
    }

    @Test func requestsTheWholeForecast() throws {
        let url = try #require(WeatherAPI.forecastURL(.init(name: "x", latitude: 51.5, longitude: -0.1), fahrenheit: false))
        let query = try #require(url.query)
        for part in ["hourly=", "daily=", "timezone=auto", "forecast_days=7", "apparent_temperature"] {
            #expect(query.contains(part), "\(part)")
        }
    }

    @Test func brokenAnswersAreRejected() {
        #expect(WeatherAPI.forecast(from: Data("{}".utf8), city: "x") == nil)
        #expect(WeatherAPI.forecast(from: Data("nope".utf8), city: "x") == nil)
    }

    /// Opt-in: asks Open-Meteo for real (PERCH_LIVE_WEATHER=1), to prove the request and parsing
    /// work against the live service, not just the sample.
    @Test func liveService() async throws {
        guard ProcessInfo.processInfo.environment["PERCH_LIVE_WEATHER"] == "1" else { return }
        let geo = try #require(WeatherAPI.geocodeURL(city: "Uxbridge"))
        let (placeData, _) = try await URLSession.shared.data(from: geo)
        let place = try #require(WeatherAPI.place(from: placeData))
        let url = try #require(WeatherAPI.forecastURL(place, fahrenheit: false))
        let (data, _) = try await URLSession.shared.data(from: url)
        let forecast = try #require(WeatherAPI.forecast(from: data, city: place.name))
        #expect(forecast.hours.count >= 8)
        #expect(forecast.days.count == 7)
        #expect(forecast.today?.sunset != nil)
        // Proof it really ran: what it got, beside the snapshots.
        if let folder = ProcessInfo.processInfo.environment["PERCH_SNAPSHOT_DIR"] {
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            let line = "\(place.name): \(forecast.now.temperatureLabel) \(forecast.now.summary), \(forecast.hours.count) hours, \(forecast.days.count) days\n"
            try line.write(toFile: folder + "/live-weather.txt", atomically: true, encoding: .utf8)
        }
    }
}

@MainActor
@Suite("Weather in the notch")
struct WeatherModelTests {
    private func makeModel() -> IslandModel {
        let defaults = UserDefaults(suiteName: "wx-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        model.screen = .sample
        return model
    }

    @Test func openingWeatherAsksForACityAndTakesTheKeyboard() {
        let model = makeModel()
        #expect(model.launcherItems.contains(.weather), "always in the grid, so it can be found")
        model.open(.weather)
        #expect(model.presentation == .nook(.weather))
        #expect(model.settings.weatherEnabled, "opening it switches it on")
        #expect(model.weatherNeedsCity)
        let pill = model.layout.pill
        _ = model.pointerMoved(to: CGPoint(x: pill.midX, y: pill.midY))
        #expect(!model.wantsEscape, "Escape belongs to the city field while it's asking")
        model.setWeatherCity("  Uxbridge ")
        #expect(model.settings.weatherCity == "Uxbridge")
        #expect(!model.weatherNeedsCity)
        #expect(model.weather.status == .loading)
        #expect(model.wantsEscape)
        model.setWeatherCity("   ")
        #expect(model.settings.weatherCity == "Uxbridge", "a blank city is ignored")
    }

    @Test func itsOwnTallerView() {
        let model = makeModel()
        model.open(.weather)
        let height = model.layout.pill.height
        model.showTab(.home)
        #expect(height > model.layout.pill.height)
        #expect(LauncherItem.weather.key == "H")
        #expect(Set(LauncherItem.allCases.map(\.key)).count == LauncherItem.allCases.count, "every shortcut key is different")
    }
}

@Suite("Weather location")
struct WeatherLocationTests {
    @Test func sourceFollowsTheSettings() {
        #expect(WeatherService.source(enabled: false, city: "London", useLocation: true) == nil)
        #expect(WeatherService.source(enabled: true, city: " London ", useLocation: false) == .city("London"))
        #expect(WeatherService.source(enabled: true, city: "London", useLocation: true) == .currentLocation, "location wins")
        #expect(WeatherService.source(enabled: true, city: "  ", useLocation: false) == nil)
    }

    @Test func permissionAndNames() {
        #expect(LocationRules.isAllowed(.authorizedAlways))
        #expect(!LocationRules.isAllowed(.denied) && !LocationRules.isAllowed(.notDetermined) && !LocationRules.isAllowed(.restricted))
        #expect(LocationRules.name(locality: "Uxbridge", subLocality: "Cowley", area: "England") == "Uxbridge")
        #expect(LocationRules.name(locality: nil, subLocality: " ", area: "England") == "England")
        #expect(LocationRules.name(locality: nil, subLocality: nil, area: nil) == "My Location")
    }

    @MainActor @Test func usingLocationFetchesWithoutACity() async throws {
        let defaults = UserDefaults(suiteName: "loc-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        var asked = 0
        model.weather.locate = {
            asked += 1
            return .failure(.denied)
        }
        model.open(.weather)
        #expect(model.weatherNeedsCity)
        model.useWeatherLocation()
        #expect(model.settings.weatherUsesLocation && model.settings.weatherCity.isEmpty)
        for _ in 0..<50 where model.weather.status != .locationDenied { try await Task.sleep(for: .milliseconds(10)) }
        #expect(asked == 1, "asked for the location straight away")
        #expect(model.weather.status == .locationDenied)
        #expect(model.weatherNeedsCity, "denied: the view offers to fix it or type a city")
        model.setWeatherCity("Uxbridge")
        #expect(!model.settings.weatherUsesLocation, "typing a city switches location off")
        model.changeWeatherPlace()
        #expect(model.weatherNeedsCity)
    }
}
