import AppKit
import SwiftUI
import Testing
@testable import NotchKit

@MainActor
@Suite("Brutal theme")
struct BrutalThemeTests {
    let screen = ScreenMetrics(size: CGSize(width: 1470, height: 956), notch: CGRect(x: 645, y: 0, width: 180, height: 32), menuBarHeight: 32)

    @Test func isSaved() {
        let defaults = UserDefaults(suiteName: "brutal-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        settings.appearance.theme = .brutal
        #expect(SettingsStore(defaults: defaults).appearance.theme == .brutal)
    }

    @Test func keepsItsEdgeEvenWhenPitchBlack() {
        var appearance = NotchAppearance.standard
        #expect(appearance.pitchBlack)
        appearance.theme = .brutal
        let engine = LayoutEngine(screen: screen, appearance: appearance)
        let open = engine.layout(for: .nook(.home), home: HomeContent(hasMedia: false), hovering: false)
        #expect(open.shadow == 1)
        #expect(open.brutalEdge == 1)

        appearance.theme = .black
        let black = LayoutEngine(screen: screen, appearance: appearance).layout(for: .nook(.home), home: HomeContent(hasMedia: false), hovering: false)
        #expect(black.shadow == 0, "pitch black Black still has no edge")
    }

    @Test func restingNotchStaysPlain() {
        var appearance = NotchAppearance.standard
        appearance.theme = .brutal
        let engine = LayoutEngine(screen: screen, appearance: appearance)
        for presentation: IslandPresentation in [.idle, .hidden(peek: false), .compact(primary: .timer, secondary: nil)] {
            #expect(engine.layout(for: presentation, homeHasMedia: false, hovering: false).brutalEdge == 0, "\(presentation)")
        }
        #expect(engine.layout(for: .alert(.timerFinished), homeHasMedia: false, hovering: false).brutalEdge > 0)
    }

    @Test func snapsOpenWithoutBounce() {
        for presentation: IslandPresentation in [.expanded(.nowPlaying), .nook(.home), .compact(primary: .timer, secondary: nil)] {
            #expect(Motion.shape(to: presentation, reduceMotion: false, theme: .brutal, style: .standard) == .spring(response: 0.3, dampingFraction: 1))
            #expect(Motion.shape(to: presentation, reduceMotion: false, theme: .brutal, style: .calm) == .spring(response: 0.36, dampingFraction: 1))
        }
        #expect(Motion.shape(to: .nook(.home), reduceMotion: true, theme: .brutal) == .easeInOut(duration: 0.2), "reduce motion still wins")
    }
}

@Suite("Full screen")
struct FullScreenDetectorTests {
    let display = CGRect(x: 0, y: 0, width: 1470, height: 956)

    @Test func aWindowCoveringTheDisplayIsFullScreen() {
        let windows = [FullScreenDetector.Window(ownerPID: 42, layer: 0, bounds: display)]
        #expect(FullScreenDetector.isFullScreen(frontmostPID: 42, windows: windows, display: display))
        #expect(!FullScreenDetector.isFullScreen(frontmostPID: 7, windows: windows, display: display), "another app's window")
    }

    @Test func zoomedWindowsAndOverlaysDontCount() {
        let zoomed = FullScreenDetector.Window(ownerPID: 42, layer: 0, bounds: CGRect(x: 0, y: 32, width: 1470, height: 924))
        let overlay = FullScreenDetector.Window(ownerPID: 42, layer: 25, bounds: display)
        #expect(!FullScreenDetector.isFullScreen(frontmostPID: 42, windows: [zoomed, overlay], display: display))
    }

    @Test func secondDisplayCoordinates() {
        // A 1920×1080 screen to the right of a 956-pt-tall primary, aligned at the top.
        let frame = CGRect(x: 1470, y: 956 - 1080, width: 1920, height: 1080)
        let rect = FullScreenDetector.windowListRect(forScreenFrame: frame, primaryHeight: 956)
        #expect(rect == CGRect(x: 1470, y: 0, width: 1920, height: 1080))
    }
}

@Suite("Headphone battery")
struct BluetoothBatteryTests {
    let json = Data("""
    {"SPBluetoothDataType":[{"controller_properties":{"controller_state":"attrib_on"},
      "device_connected":[
        {"Sarhan’s AirPods Pro":{"device_batteryLevelCase":"40%","device_batteryLevelLeft":"88%","device_batteryLevelRight":"91%"}},
        {"WH-1000XM5":{"device_batteryLevelMain":"60%"}},
        {"Magic Keyboard":{"device_minorType":"Keyboard"}}
      ],
      "device_not_connected":[{"Old Buds":{"device_batteryLevelMain":"10%"}}]}]}
    """.utf8)

    @Test func lowerEarbudForAirPods() {
        #expect(BluetoothBattery.level(named: "Sarhan’s AirPods Pro", inSystemProfilerJSON: json) == 88)
        #expect(BluetoothBattery.level(named: "sarhan’s airpods pro", inSystemProfilerJSON: json) == 88, "names match whatever the case")
    }

    @Test func mainBatteryOtherwise() {
        #expect(BluetoothBattery.level(named: "WH-1000XM5", inSystemProfilerJSON: json) == 60)
    }

    @Test func nothingWhenUnknownDisconnectedOrBroken() {
        #expect(BluetoothBattery.level(named: "Magic Keyboard", inSystemProfilerJSON: json) == nil)
        #expect(BluetoothBattery.level(named: "Old Buds", inSystemProfilerJSON: json) == nil)
        #expect(BluetoothBattery.level(named: "Anything", inSystemProfilerJSON: Data("nope".utf8)) == nil)
        #expect(BluetoothBattery.percent("140%") == nil)
    }
}

@Suite("Weather")
struct WeatherTests {
    @Test func parsesPlaceAndCurrentWeather() throws {
        let geo = Data(#"{"results":[{"name":"Uxbridge","latitude":51.54,"longitude":-0.48}]}"#.utf8)
        let place = try #require(WeatherAPI.place(from: geo))
        #expect(place.name == "Uxbridge")
        let forecast = Data(#"{"current":{"temperature_2m":13.6,"weather_code":61,"is_day":0}}"#.utf8)
        let now = try #require(WeatherAPI.now(from: forecast, city: place.name))
        #expect(now.temperatureLabel == "14°")
        #expect(now.symbolName == "cloud.rain.fill")
        #expect(!now.isDay)
        #expect(WeatherAPI.place(from: Data(#"{"generationtime_ms":0.1}"#.utf8)) == nil, "unknown city")
    }

    @Test func dayAndNightSymbols() {
        #expect(WeatherCodes.symbol(for: 0, isDay: true) == "sun.max.fill")
        #expect(WeatherCodes.symbol(for: 0, isDay: false) == "moon.stars.fill")
        #expect(WeatherCodes.symbol(for: 95, isDay: true) == "cloud.bolt.rain.fill")
        #expect(WeatherCodes.symbol(for: 1234, isDay: true) == "cloud.fill")
    }

    @Test func requestsCarryOnlyTheCityThenCoordinates() throws {
        let geo = try #require(WeatherAPI.geocodeURL(city: "São Paulo"))
        #expect(geo.host == "geocoding-api.open-meteo.com")
        #expect(geo.query?.contains("name=S%C3%A3o%20Paulo") == true)
        let forecast = try #require(WeatherAPI.forecastURL(.init(name: "X", latitude: 1.5, longitude: -2), fahrenheit: true))
        #expect(forecast.query?.contains("temperature_unit=fahrenheit") == true)
    }
}

@MainActor
@Suite("New settings")
struct NewSettingsTests {
    @Test func startOffAndAreRemembered() {
        let defaults = UserDefaults(suiteName: "new-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.hideInFullScreen, "on from the start")
        #expect(!settings.hideFromScreenCapture && !settings.weatherEnabled)
        #expect(!settings.headphoneAlertsEnabled, "macOS already shows its own banner")
        #expect(!settings.checksForUpdates, "the fork never pulls the original app's updates")
        settings.hideInFullScreen = false
        settings.hideFromScreenCapture = true
        settings.weatherEnabled = true
        settings.weatherCity = "Uxbridge"
        let reopened = SettingsStore(defaults: defaults)
        #expect(!reopened.hideInFullScreen && reopened.hideFromScreenCapture && reopened.weatherEnabled)
        #expect(reopened.weatherCity == "Uxbridge")
    }

    @Test func searchFindsThem() {
        #expect(SettingsSearch.results(for: "full screen").contains { $0.title == "Privacy & Focus" })
        #expect(SettingsSearch.results(for: "weather").contains { $0.title == "Weather" })
        #expect(SettingsSearch.results(for: "brutal").contains { $0.title == "Appearance" })
    }
}

@Suite("Pip")
struct PipTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func moodOrder() {
        #expect(Pip.mood(hovering: true, celebratedAt: now, now: now, hour: 3, secondsSinceInput: 9_999) == .curious, "hover wins")
        #expect(Pip.mood(hovering: false, celebratedAt: now.addingTimeInterval(-1), now: now, hour: 3, secondsSinceInput: 0) == .happy)
        #expect(Pip.mood(hovering: false, celebratedAt: now.addingTimeInterval(-10), now: now, hour: 14, secondsSinceInput: 0) == .awake, "the smile fades")
        #expect(Pip.mood(hovering: false, celebratedAt: now.addingTimeInterval(2), now: now, hour: 14, secondsSinceInput: 0) == .awake, "waits for the alert to finish")
        #expect(Pip.mood(hovering: false, celebratedAt: nil, now: now, hour: 2, secondsSinceInput: 0) == .asleep, "night")
        #expect(Pip.mood(hovering: false, celebratedAt: nil, now: now, hour: 14, secondsSinceInput: 600) == .asleep, "you're away")
        #expect(Pip.mood(hovering: false, celebratedAt: nil, now: now, hour: 23, secondsSinceInput: 5) == .awake)
    }

    @Test func gazeFollowsThePointerAndStaysInBounds() {
        let camera = CGPoint(x: 735, y: 956)
        #expect(Pip.gaze(pointer: camera, camera: camera, screenWidth: 1470) == .zero)
        let farLeftBelow = Pip.gaze(pointer: CGPoint(x: -5000, y: -5000), camera: camera, screenWidth: 1470)
        #expect(farLeftBelow.dx == -1 && farLeftBelow.dy == 1)
        #expect(Pip.gaze(pointer: CGPoint(x: 1102.5, y: 956), camera: camera, screenWidth: 1470).dx == 0.5)
        #expect(Pip.gaze(pointer: .zero, camera: camera, screenWidth: 0) == .zero)
    }

    @Test func blinksAreIrregularButBounded() {
        let intervals = (0..<50).map(Pip.blinkInterval(seed:))
        #expect(intervals.allSatisfy { (2.5...6).contains($0) })
        #expect(Set(intervals).count > 10)
    }

    @Test func celebratesGoodNewsOnly() {
        #expect(IslandModel.isCelebration(.agentFinished(agent: "Claude", project: "x")))
        #expect(IslandModel.isCelebration(.shortcut(name: "x", succeeded: true)))
        #expect(!IslandModel.isCelebration(.shortcut(name: "x", succeeded: false)))
        #expect(!IslandModel.isCelebration(.lowBattery(level: 10)))
        #expect(IslandModel.isCelebration(.charging(level: 100, isCharging: true)))
        #expect(!IslandModel.isCelebration(.charging(level: 50, isCharging: true)))
    }

    @MainActor @Test func onByDefaultAndSaved() {
        let defaults = UserDefaults(suiteName: "pip-\(UUID().uuidString)")!
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.appearance.companion)
        settings.appearance.companion = false
        #expect(!SettingsStore(defaults: defaults).appearance.companion)
        #expect(!NotchAppearance.standard.companion, "the layout engine's own default is unchanged")
    }
}

@Suite("Stats details")
struct StatsDetailsTests {
    @Test func batteryFromAppleSilicon() throws {
        let properties: [String: Any] = [
            "CurrentCapacity": 76, "MaxCapacity": 100, "IsCharging": false, "ExternalConnected": false,
            "TimeRemaining": 245, "CycleCount": 312, "AppleRawMaxCapacity": 4_600, "DesignCapacity": 5_000,
            "Temperature": 3_120, "Voltage": 12_000, "InstantAmperage": -700,
        ]
        let battery = try #require(BatteryInfo.parse(properties))
        #expect(battery.level == 76 && !battery.isCharging && !battery.onPower)
        #expect(battery.minutesRemaining == 245 && battery.cycleCount == 312)
        #expect(battery.health == 0.92)
        #expect(battery.temperature == 31.2)
        #expect(battery.watts == -8.4)
        #expect(BatteryText.state(battery) == "4h 5m left")
        #expect(BatteryText.health(battery) == "Health 92% · 312 cycles")
        #expect(BatteryText.power(battery) == "8.4 W · 31°C")
    }

    @Test func batteryCharging() throws {
        let properties: [String: Any] = [
            "CurrentCapacity": 2_000, "MaxCapacity": 4_000, "IsCharging": true, "ExternalConnected": true,
            "TimeRemaining": 65_535, "Voltage": 12_500, "Amperage": 4_294_966_296 as UInt64,
            "AdapterDetails": ["Watts": 96],
        ]
        let battery = try #require(BatteryInfo.parse(properties))
        #expect(battery.level == 50, "Intel reports mAh; still a percentage here")
        #expect(battery.minutesRemaining == nil, "still estimating")
        #expect(battery.adapterWatts == 96)
        #expect(battery.watts == -12.5, "a wrapped unsigned amperage reads as negative")
        #expect(BatteryText.state(battery) == "Charging")
        #expect(BatteryInfo.parse(["Voltage": 1]) == nil, "no battery on a desktop")
    }

    @Test func gpuAndCPUSplit() {
        #expect(StatsMath.gpuUtilization(["Device Utilization %": 37]) == 0.37)
        #expect(StatsMath.gpuUtilization(["Other": 1]) == nil)
        let old = StatsMath.CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let new = StatsMath.CPUTicks(user: 30, system: 10, idle: 50, nice: 10)
        let split = StatsMath.cpuSplit(from: old, to: new)
        #expect(split.user == 0.4 && split.system == 0.1)
    }

    @Test func busiestAppsFirst() {
        let old: [Int32: UInt64] = [1: 0, 2: 1_000_000_000, 3: 5_000_000_000, 4: 0]
        let new: [Int32: UInt64] = [1: 3_000_000_000, 2: 2_000_000_000, 3: 4_000_000_000, 5: 9_000_000_000, 4: 1_000]
        let top = StatsMath.topProcesses(old: old, new: new, names: [1: "Xcode"], seconds: 2)
        #expect(top.map(\.pid) == [1, 2], "pid 3 went backwards, 5 is new, 4 is idle")
        #expect(top.first?.cpu == 1.5 && top.first?.name == "Xcode")
        #expect(top.last?.name == "pid 2")
    }

    @Test func labels() {
        #expect(StatsMath.duration(59) == "0m")
        #expect(StatsMath.duration(5 * 3600 + 12 * 60) == "5h 12m")
        #expect(StatsMath.duration(3 * 86_400 + 4 * 3600) == "3d 4h")
        #expect(StatsMath.appending(1, to: Array(repeating: 0, count: 60)).count == 60)
        #expect(StatsMath.thermalLabel(2) == "Hot")
    }

    @Test func sparklineFillsFromTheRight() {
        let points = SparklineMath.points([0, 1], in: CGSize(width: 59, height: 10), normalize: false)
        #expect(points == [CGPoint(x: 58, y: 10), CGPoint(x: 59, y: 0)])
        let network = SparklineMath.points([500, 1000], in: CGSize(width: 59, height: 10), normalize: true)
        #expect(network.last?.y == 0 && network.first?.y == 5)
        #expect(SparklineMath.points([1], in: CGSize(width: 10, height: 10), normalize: false).isEmpty)
    }
}

@Suite("Clipboard size")
struct ClipboardSizeTests {
    @Test func keepsAsManyAsAskedAndTrimsWhenItShrinks() {
        var history = ClipboardHistory()
        history.setLimit(50)
        for index in 0..<60 { history.add("item \(index)") }
        #expect(history.entries.count == 50)
        #expect(history.entries.first?.text == "item 59")
        history.setLimit(20)
        #expect(history.entries.count == 20, "the oldest go")
        #expect(history.entries.last?.text == "item 40")
    }

    @MainActor @Test func settingIsRememberedAndValidated() {
        let defaults = UserDefaults(suiteName: "clip-\(UUID().uuidString)")!
        #expect(SettingsStore(defaults: defaults).clipboardLimit == 20)
        SettingsStore(defaults: defaults).clipboardLimit = 100
        #expect(SettingsStore(defaults: defaults).clipboardLimit == 100)
        defaults.set(7, forKey: "clipboard.limit")
        #expect(SettingsStore(defaults: defaults).clipboardLimit == 20, "an odd saved value falls back")
    }
}

@Suite("Battery data on Apple silicon")
struct NestedBatteryTests {
    @Test func readsDesignCapacityFromBatteryData() throws {
        let properties: [String: Any] = [
            "CurrentCapacity": 92, "MaxCapacity": 100, "AppleRawMaxCapacity": 4_500,
            "BatteryData": ["DesignCapacity": 5_000, "Temperature": 2_950] as [String: Any],
        ]
        let battery = try #require(BatteryInfo.parse(properties))
        #expect(battery.health == 0.9)
        #expect(battery.temperature == 29.5)
    }
}

@Suite("Pip stays still")
struct PipQuietTests {
    @Test func smallPointerMovesDontMoveTheEyes() {
        let camera = CGPoint(x: 735, y: 956)
        let a = Pip.gaze(pointer: CGPoint(x: 900, y: 600), camera: camera, screenWidth: 1470)
        let b = Pip.gaze(pointer: CGPoint(x: 910, y: 606), camera: camera, screenWidth: 1470)
        #expect(a == b)
        #expect(a.dx.truncatingRemainder(dividingBy: 0.25) == 0)
    }
}

@Suite("Alerts are spoken")
struct AlertAnnouncementTests {
    @Test func saysWhatAppeared() {
        #expect(IslandAlert.timerFinished.announcement == "Timer finished")
        #expect(IslandAlert.headphones(name: "AirPods", symbol: "airpods", battery: 80).announcement == "AirPods connected, 80 percent")
        #expect(IslandAlert.level(.volume, value: 0.5, muted: false).announcement == nil, "the system already speaks volume")
    }
}

@MainActor
@Suite("Escape closes the notch")
struct EscapeTests {
    @Test func onlyWhileThePointerIsOnTheOpenNotch() {
        let defaults = UserDefaults(suiteName: "esc-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        model.screen = .sample
        #expect(!model.wantsEscape, "closed")
        model.showTab(.home)
        #expect(!model.wantsEscape, "open, but the pointer is elsewhere: Escape stays with your app")
        let pill = model.layout.pill
        _ = model.pointerMoved(to: CGPoint(x: pill.midX, y: pill.midY))
        #expect(model.wantsEscape)
        model.isSearchingClipboard = true
        #expect(!model.wantsEscape, "the search field needs Escape")
        model.isSearchingClipboard = false
        model.collapse()
        #expect(!model.wantsEscape)
    }
}

@Suite("Pip's ears are part of the notch")
struct PipHitTests {
    @Test func theEarsAnswerThePointer() {
        let screen = ScreenMetrics(size: CGSize(width: 1470, height: 956), notch: CGRect(x: 645, y: 0, width: 180, height: 32), menuBarHeight: 32)
        var appearance = NotchAppearance.standard
        let plain = LayoutEngine(screen: screen, appearance: appearance).notchHoverRect
        appearance.companion = true
        let withPip = LayoutEngine(screen: screen, appearance: appearance).notchHoverRect
        #expect(withPip.width == plain.width + 2 * IslandMetrics.pipEar)
        #expect(withPip.midX == plain.midX)
    }
}

@Suite("Pip's little touches")
struct PipTouchesTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func smilesWhenYouComeBack() {
        #expect(Pip.isWakingUp(from: .asleep, to: .awake))
        #expect(Pip.isWakingUp(from: .asleep, to: .curious))
        #expect(!Pip.isWakingUp(from: .awake, to: .asleep))
        #expect(!Pip.isWakingUp(from: .happy, to: .awake))
    }

    @Test func keepAwakeKeepsPipUp() {
        #expect(Pip.mood(hovering: false, celebratedAt: nil, now: now, hour: 3, secondsSinceInput: 9_999, keptAwake: true) == .awake)
        #expect(Pip.mood(hovering: false, celebratedAt: nil, now: now, hour: 3, secondsSinceInput: 9_999) == .asleep)
    }

    @MainActor @Test func wakingUpCelebrates() {
        let defaults = UserDefaults(suiteName: "pip-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        #expect(model.pipCelebratedAt == nil)
        model.pipWokeUp()
        let at = try? #require(model.pipCelebratedAt)
        #expect(at.map { Date().timeIntervalSince($0) < 1 } == true)
    }

    @MainActor @Test func menuBarIconIsATemplate() {
        let image = PipGlyph.menuBarImage()
        #expect(image.isTemplate, "macOS tints it for light and dark menu bars")
        #expect(image.size == NSSize(width: 24, height: 16))
    }
}

@Suite("Automation permission messages")
struct AutomationRulesTests {
    @Test func saysWhatToDo() {
        #expect(AutomationRules.message(for: noErr, appName: "Safari") == nil)
        #expect(AutomationRules.message(for: -1743, appName: "Safari")?.contains("Privacy & Security › Automation") == true)
        #expect(AutomationRules.message(for: -600, appName: "Pages") == "Pages isn't running any more.")
        #expect(AutomationRules.message(for: -50, appName: "Pages")?.contains("-50") == true)
    }
}
