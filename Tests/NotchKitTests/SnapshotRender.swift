import AppKit
import SwiftUI
import Testing
@testable import NotchKit

/// Renders real views to PNGs so they can be looked at without a screen recording. Runs only
/// when PERCH_SNAPSHOT_DIR is set (the build script sets it on request); otherwise it's a no-op.
@MainActor
@Suite("Snapshots")
struct SnapshotRender {
    private var folder: URL? {
        ProcessInfo.processInfo.environment["PERCH_SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func save<V: View>(_ view: V, size: CGSize, as name: String) throws {
        guard let folder else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .dark))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            Issue.record("couldn't render \(name)")
            return
        }
        try png.write(to: folder.appendingPathComponent(name + ".png"))
    }

    @Test(arguments: [false, true]) func statsPanel(brutal: Bool) async throws {
        guard folder != nil else { return }
        let defaults = UserDefaults(suiteName: "snap-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        model.screen = .sample
        model.open(.stats)
        // Two readings two seconds apart, so CPU, cores and processes have something to show.
        try await Task.sleep(for: .seconds(4.6))
        let width = IslandMetrics.Nook.width
        let height = IslandMetrics.Nook.statsBody
        let view = StatsPanelBody(model: model)
            .padding(.horizontal, 18)
            .frame(width: width, height: height)
            .background(Color.black)
            .environment(\.brutal, brutal)
        try save(view, size: CGSize(width: width, height: height), as: brutal ? "stats-brutal" : "stats-black")
        model.collapse()
    }

    @Test func pipOnTheNotch() throws {
        guard folder != nil else { return }
        let defaults = UserDefaults(suiteName: "snap-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        let notch = CGRect(x: 130, y: 0, width: 180, height: 32)
        let view = ZStack(alignment: .topLeading) {
            Color(red: 0.25, green: 0.35, blue: 0.55)
            PipLayer(model: model, notch: notch, scale: 1, brutal: true)
        }
        try save(view, size: CGSize(width: 440, height: 60), as: "pip")
    }

    /// The two newest panels, with a few colours and dates in them.
    @Test(arguments: [false, true]) func picks(brutal: Bool) throws {
        guard folder != nil else { return }
        let defaults = UserDefaults(suiteName: "snap-\(UUID().uuidString)")!
        let picks = PicksStore(defaults: defaults)
        for hex in ["#2B2D42", "#8D99AE", "#EF233C", "#FFB703", "#219EBC", "#8338EC"] { picks.add(PickedColor(hex: hex)!) }
        picks.addCountdown("Trip to Dhaka", date: Date().addingTimeInterval(86400 * 40))
        picks.addCountdown("Elanco interview", date: Date().addingTimeInterval(86400 * 4))
        picks.addCountdown("Algorithms exam", date: Date().addingTimeInterval(86400 * 1.2))
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil, defaults: nil), notes: NotesStore(defaults: defaults), picks: picks)
        let width = IslandMetrics.Nook.width
        let height = IslandMetrics.Nook.body
        let view = VStack(spacing: 16) {
            ColorsPanelBody(model: model).frame(height: height)
            CountdownsPanelBody(model: model).frame(height: height)
        }
        .padding(18)
        .frame(width: width + 36, height: height * 2 + 52)
        .background(Color.black)
        .environment(\.brutal, brutal)
        try save(view, size: CGSize(width: width + 36, height: height * 2 + 52), as: brutal ? "picks-brutal" : "picks-black")
    }

    /// The compact music shape coloured by the song, on Black and on Brutal.
    @Test func songGlow() throws {
        guard folder != nil else { return }
        let engine = LayoutEngine(screen: .sample, appearance: .standard)
        let layout = engine.layout(for: .compact(primary: .nowPlaying, secondary: nil), home: HomeContent(hasLyrics: true), hovering: false)
        let pink = Color(red: 1, green: 0.42, blue: 0.7)
        let view = VStack(spacing: 0) {
            ForEach([false, true], id: \.self) { brutal in
                ZStack(alignment: .topLeading) {
                    Color(white: 0.85)
                    IslandSurface(layout: layout, pulse: 0, liquid: false, brutal: brutal, songColor: pink)
                }
                .frame(width: layout.canvasSize.width, height: 90, alignment: .top)
                .clipped()
            }
        }
        try save(view, size: CGSize(width: layout.canvasSize.width, height: 180), as: "song-glow")
    }

    /// The whole notch window as the app draws it, for each main view, over a plain wallpaper.
    @Test(arguments: NotchTheme.allCases) func screens(theme: NotchTheme) async throws {
        guard folder != nil else { return }
        let defaults = UserDefaults(suiteName: "snap-\(UUID().uuidString)")!
        let picks = PicksStore(defaults: defaults)
        picks.addCountdown("Algorithms exam", date: Date().addingTimeInterval(86400 * 9))
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil, defaults: nil), notes: NotesStore(defaults: defaults), picks: picks)
        model.screen = .sample
        model.settings.appearance.theme = theme
        let display = DisplayContext()
        display.id = model.activeDisplayID
        display.metrics = .sample
        func shot(_ name: String) throws {
            let layout = model.layout(onDisplay: display.id, metrics: display.metrics)
            let view = ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 0.36, green: 0.45, blue: 0.62), Color(red: 0.55, green: 0.42, blue: 0.5)], startPoint: .top, endPoint: .bottom)
                IslandRootView(model: model, display: display)
            }
            try save(view, size: layout.canvasSize, as: "screen-\(theme.rawValue)-" + name)
        }
        try shot("rest")
        model.showTab(.home); try shot("home")
        model.showTab(.tray); try shot("tray")
        model.showTab(.clipboard); try shot("clipboard")
        model.showTab(.launcher); try shot("grid")
        model.open(.stats); try shot("stats")
        model.open(.reminders); try shot("reminders")
        model.open(.weather); try shot("weather-tab")
        model.open(.timer); try shot("timers")
        model.showTab(.calendar); try shot("calendar")
        model.open(.countdowns); try shot("countdowns")
        model.open(.colors); try shot("colors")
        model.collapse()
        model.startTimer(300); try shot("compact-timer")
        model.expand(.activity(.timer)); try shot("expanded-timer")
        model.collapse()
        model.cancelTimer()
    }

    @Test func weather() throws {
        guard folder != nil else { return }
        let forecast = try #require(WeatherAPI.forecast(from: WeatherForecastTests.week(), city: "London", now: WeatherForecastTests.noon))
        let width = IslandMetrics.Nook.width, height = IslandMetrics.Nook.weatherBody
        let view = WeatherForecastView(forecast: forecast, status: .ready, updatedAt: Date())
            .padding(.horizontal, 20)
            .frame(width: width, height: height)
            .background(Color.black)
        try save(view, size: CGSize(width: width, height: height), as: "weather")

        let defaults = UserDefaults(suiteName: "snap-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        let prompt = WeatherPanelBody(model: model)
            .frame(width: width, height: height)
            .background(Color.black)
        try save(prompt, size: CGSize(width: width, height: height), as: "weather-setup")
    }

    /// The menu bar icon on a light and a dark bar, big enough to see.
    @Test func menuBarIcon() throws {
        guard let folder else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let canvas = NSImage(size: NSSize(width: 240, height: 64), flipped: false) { rect in
            for (index, (bar, ink)) in [(NSColor(white: 0.92, alpha: 1), NSColor.black), (NSColor(white: 0.12, alpha: 1), NSColor.white)].enumerated() {
                let half = NSRect(x: CGFloat(index) * rect.width / 2, y: 0, width: rect.width / 2, height: rect.height)
                bar.setFill(); half.fill()
                for (offset, asleep) in [(0.0, false), (54.0, true)] {
                    let glyph = PipGlyph.menuBarImage(asleep: asleep)
                    let tinted = NSImage(size: glyph.size, flipped: false) { r in
                        glyph.draw(in: r); ink.set(); r.fill(using: .sourceAtop); return true
                    }
                    tinted.draw(in: NSRect(x: half.minX + 16 + offset, y: 16, width: 40, height: 32))
                }
            }
            return true
        }
        guard let tiff = canvas.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try png.write(to: folder.appendingPathComponent("menubar-icon.png"))
    }

    /// The tray with files in it, in Black and Brutal.
    @Test func trayWithFiles() throws {
        guard folder != nil else { return }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tray-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let names = ["Week 7 meeting notes.pdf", "Peeko icon.png", "CV final.docx", "budget.xlsx", "holiday photo.jpg", "slides.key"]
        let urls = try names.map { name -> URL in
            let url = dir.appendingPathComponent(name)
            try Data("x".utf8).write(to: url)
            return url
        }
        for theme in [NotchTheme.black, .brutal] {
            let defaults = UserDefaults(suiteName: "snap-\(UUID().uuidString)")!
            // defaults: nil, so the pin below is never saved where other tests would find it.
            let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil, defaults: nil), notes: NotesStore(defaults: defaults))
            model.screen = .sample
            model.settings.appearance.theme = theme
            #expect(model.tray.add(urls) == urls.count)
            model.tray.togglePin(model.tray.ordered[1].id)
            let display = DisplayContext()
            display.id = model.activeDisplayID
            display.metrics = .sample
            model.showTab(.tray)
            let layout = model.layout(onDisplay: display.id, metrics: display.metrics)
            let view = ZStack(alignment: .topLeading) {
                Color(red: 0.4, green: 0.45, blue: 0.6)
                IslandRootView(model: model, display: display)
            }
            try save(view, size: layout.canvasSize, as: "tray-\(theme.rawValue)")
        }
    }
}
