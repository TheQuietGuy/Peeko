import Foundation
import Testing
@testable import NotchKit

@MainActor
@Suite("Colour Picker and Countdowns")
struct PicksTests {
    @Test func colourCodes() throws {
        let color = try #require(PickedColor(hex: "#1A2B3C"))
        #expect(color.hex == "#1A2B3C")
        #expect(color.rgb == "rgb(26, 43, 60)")
        #expect(color.hsl == "hsl(210, 40%, 17%)")
        #expect(color.swiftUI == "Color(red: 0.102, green: 0.169, blue: 0.235)")
        #expect(PickedColor(hex: "ff0000")?.hsl == "hsl(0, 100%, 50%)")
        #expect(PickedColor(hex: "#ff00ff")?.hsl == "hsl(300, 100%, 50%)")
        #expect(PickedColor(hex: "#12345") == nil)
        #expect(PickedColor(hex: "zzzzzz") == nil)
        #expect(PickedColor(red: 1.0, green: 0.5, blue: 0).hex == "#FF8000")
        #expect(PickedColor(red: 2.0, green: -1, blue: 0).hex == "#FF0000", "clamped")
        #expect(PickedColor(hex: "#FFFFFF")!.isLight && !PickedColor(hex: "#000000")!.isLight)
    }

    @Test func recentColoursAreNewestFirstWithoutRepeats() {
        let defaults = UserDefaults(suiteName: "picks-\(UUID().uuidString)")!
        let store = PicksStore(defaults: defaults)
        let red = PickedColor(red: 255, green: 0, blue: 0), blue = PickedColor(red: 0, green: 0, blue: 255)
        store.add(red)
        store.add(blue)
        store.add(red)
        #expect(store.colors == [red, blue])
        for value in 0..<20 { store.add(PickedColor(red: value, green: 0, blue: 0)) }
        #expect(store.colors.count == PicksStore.colorCapacity)
        #expect(PicksStore(defaults: defaults).colors == store.colors, "kept between launches")
    }

    @Test func countdownLabelsAndOrder() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 23, minute: 30))!
        func day(_ d: Int, hour: Int = 9) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour))! }
        let exam = Countdown(title: "Exam", date: day(24, hour: 1))
        #expect(exam.daysLeft(from: now, calendar: calendar) == 1, "calendar days, not 24-hour blocks")
        #expect(exam.label(from: now, calendar: calendar) == ("1", "day"))
        #expect(Countdown(title: "x", date: day(23)).label(from: now, calendar: calendar) == ("Today", ""))
        #expect(Countdown(title: "x", date: day(30)).label(from: now, calendar: calendar) == ("7", "days"))
        #expect(Countdown(title: "x", date: day(20)).label(from: now, calendar: calendar) == ("3", "days ago"))
        let trip = Countdown(title: "Trip", date: day(30)), past = Countdown(title: "Past", date: day(20)), older = Countdown(title: "Older", date: day(2))
        #expect(Countdown.ordered([past, trip, older, exam], now: now, calendar: calendar).map(\.title) == ["Exam", "Trip", "Past", "Older"])
    }

    @Test func countdownsNeedANameAndAreKept() {
        let defaults = UserDefaults(suiteName: "picks-\(UUID().uuidString)")!
        let store = PicksStore(defaults: defaults)
        store.addCountdown("   ", date: .now)
        #expect(store.countdowns.isEmpty)
        store.addCountdown("  Algorithms exam ", date: .now)
        #expect(store.countdowns.map(\.title) == ["Algorithms exam"])
        #expect(PicksStore(defaults: defaults).countdowns == store.countdowns)
        store.removeCountdown(store.countdowns[0].id)
        #expect(store.countdowns.isEmpty)
    }

    @Test func newTilesHaveTheirOwnPanels() {
        #expect(LauncherItem.forTab(.colors, stopwatch: false) == .colors)
        #expect(LauncherItem.forTab(.countdowns, stopwatch: false) == .countdowns)
        #expect(LauncherItem.colors.shortcutLabel == "⌃⌥X")
        #expect(HotKeys.keyCode("Y") != nil)
    }
}
