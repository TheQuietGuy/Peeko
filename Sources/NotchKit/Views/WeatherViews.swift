import AppKit
import SwiftUI

// Weather: a small Weather app in the notch, laid out like Apple's. Now on the left, the next
// hours beside it, details under them, and the week along the bottom.

struct WeatherPanelBody: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let weather = model.weather
        Group {
            if model.weatherNeedsCity {
                WeatherCityPrompt(model: model, status: weather.status)
            } else if let forecast = weather.forecast {
                WeatherForecastView(forecast: forecast, status: weather.status, updatedAt: weather.updatedAt,
                                    isCurrentLocation: model.settings.weatherUsesLocation) {
                    model.changeWeatherPlace()
                }
            } else {
                WeatherMessage(status: weather.status)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Asked right in the notch the first time, so setting Weather up is one step.
private struct WeatherCityPrompt: View {
    let model: IslandModel
    let status: WeatherService.Status
    @State private var draft = ""
    @FocusState private var focused: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        VStack(spacing: 10 * s) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 30 * s))
            Text(title)
                .font(.system(size: 14 * s, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8 * s) {
                if status == .locationDenied {
                    Button("Allow Location…") { WeatherCityPrompt.openLocationSettings() }
                        .buttonStyle(QuickActionStyle(tint: NotchColor.blue, scale: s))
                } else {
                    Button { model.useWeatherLocation() } label: {
                        Label("Use My Location", systemImage: "location.fill")
                    }
                    .buttonStyle(QuickActionStyle(tint: NotchColor.blue, scale: s))
                }
                Text("or")
                    .font(.system(size: 11 * s, weight: .medium))
                    .foregroundStyle(NotchColor.secondaryText)
                TextField("City", text: $draft, prompt: Text("e.g. London"))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13 * s, weight: .medium))
                    .padding(.horizontal, 10 * s)
                    .frame(width: 150 * s, height: 28 * s)
                    .background(RoundedRectangle(cornerRadius: 8 * s, style: .continuous).fill(Color.white.opacity(0.1)))
                    .focused($focused)
                    .onSubmit(save)
                Button("Show", action: save)
                    .buttonStyle(QuickActionStyle(tint: .white, scale: s))
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("Only the place is sent, to Open-Meteo. Change it any time in Settings.")
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(NotchColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = true }
    }

    private func save() {
        model.setWeatherCity(draft)
    }

    private var title: LocalizedStringKey {
        switch status {
        case .unknownCity: "Couldn't find that city. Try another?"
        case .locationDenied: "Perch isn't allowed to use your location."
        default: "Where should Weather be for?"
        }
    }

    /// System Settings › Privacy & Security › Location Services.
    static func openLocationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct WeatherMessage: View {
    let status: WeatherService.Status
    @Environment(\.notchScale) private var s

    var body: some View {
        VStack(spacing: 8 * s) {
            Image(systemName: status == .unavailable ? "wifi.exclamationmark" : "cloud.sun")
                .font(.system(size: 26 * s))
                .foregroundStyle(NotchColor.secondaryText)
            Text(status == .unavailable ? "Can't reach the weather right now." : "Getting the weather…")
                .font(.system(size: 13 * s, weight: .medium))
                .foregroundStyle(NotchColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The forecast: now, the hours, details and the week.
struct WeatherForecastView: View {
    let forecast: WeatherForecast
    let status: WeatherService.Status
    let updatedAt: Date?
    var isCurrentLocation = false
    var changeCity: () -> Void = {}
    @Environment(\.notchScale) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * s) {
            HStack(alignment: .top, spacing: 12 * s) {
                WeatherNowBlock(forecast: forecast, status: status, updatedAt: updatedAt, isCurrentLocation: isCurrentLocation, changeCity: changeCity)
                    .frame(width: 168 * s, alignment: .leading)
                VStack(alignment: .leading, spacing: 6 * s) {
                    WeatherHours(hours: Array(forecast.hours.prefix(8)), zone: forecast.timeZone)
                    WeatherDetails(forecast: forecast)
                }
            }
            .frame(height: 112 * s)
            WeatherWeek(forecast: forecast)
        }
    }
}

private struct WeatherNowBlock: View {
    let forecast: WeatherForecast
    let status: WeatherService.Status
    let updatedAt: Date?
    let isCurrentLocation: Bool
    let changeCity: () -> Void
    @Environment(\.notchScale) private var s

    var body: some View {
        let now = forecast.now
        VStack(alignment: .leading, spacing: 2 * s) {
            Button(action: changeCity) {
                HStack(spacing: 4 * s) {
                    // Filled arrow: following you. Outline: a city you picked.
                    Image(systemName: isCurrentLocation ? "location.fill" : "location").font(.system(size: 9 * s, weight: .bold))
                    Text(now.city).lineLimit(1)
                }
                .font(.system(size: 13 * s, weight: .semibold))
                .foregroundStyle(.white)
            }
            .buttonStyle(PressableButtonStyle())
            .help("Change city")
            HStack(alignment: .center, spacing: 6 * s) {
                Text(now.temperatureLabel)
                    .font(.system(size: 44 * s, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Image(systemName: now.symbolName)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 28 * s))
            }
            Text(now.summary)
                .font(.system(size: 12 * s, weight: .semibold))
                .foregroundStyle(.white)
            if let today = forecast.today {
                Text("H:\(Int(today.high.rounded()))°  L:\(Int(today.low.rounded()))°")
                    .font(.system(size: 11 * s, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(NotchColor.secondaryText)
            }
            if status == .unavailable, let updatedAt {
                Text("Offline · from \(updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9.5 * s, weight: .medium))
                    .foregroundStyle(NotchColor.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The next hours, like the strip at the top of Apple's Weather.
private struct WeatherHours: View {
    let hours: [WeatherForecast.Hour]
    let zone: TimeZone
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                VStack(spacing: 4 * s) {
                    Text(index == 0 ? "Now" : WeatherText.hour(hour.time, zone: zone))
                        .font(.system(size: 10 * s, weight: .semibold))
                        .foregroundStyle(index == 0 ? .white : NotchColor.secondaryText)
                    Image(systemName: hour.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 15 * s))
                        .frame(height: 18 * s)
                    Text("\(Int(hour.temperature.rounded()))°")
                        .font(.system(size: 12 * s, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(WeatherText.rain(hour.rainChance))
                        .font(.system(size: 9 * s, weight: .semibold))
                        .foregroundStyle(Color(red: 0.4, green: 0.75, blue: 1))
                        .frame(height: 10 * s)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 6 * s)
        .background(RoundedRectangle(cornerRadius: 12 * s, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

private struct WeatherDetails: View {
    let forecast: WeatherForecast
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 10 * s) {
            if let rain = forecast.rainAlert {
                detail("umbrella.fill", WeatherText.rainAlert(rain, zone: forecast.timeZone), tint: Color(red: 0.4, green: 0.75, blue: 1))
            }
            if let feels = forecast.feelsLike { detail("thermometer.medium", "Feels \(Int(feels.rounded()))°") }
            if let humidity = forecast.humidity { detail("humidity.fill", "\(humidity)%") }
            if let wind = forecast.wind { detail("wind", WeatherText.wind(wind)) }
            if let sunset = forecast.today?.sunset { detail("sunset.fill", WeatherText.hour(sunset, zone: forecast.timeZone, minutes: true)) }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func detail(_ symbol: String, _ text: String, tint: Color = NotchColor.secondaryText) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 10.5 * s, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
    }
}

/// The week, with each day's low-to-high bar on the week's range, like Apple's 10-day list
/// turned on its side.
private struct WeatherWeek: View {
    let forecast: WeatherForecast
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 6 * s) {
            ForEach(Array(forecast.days.prefix(7).enumerated()), id: \.element.id) { index, day in
                VStack(spacing: 3 * s) {
                    Text(index == 0 ? "Today" : WeatherText.weekday(day.date, zone: forecast.timeZone))
                        .font(.system(size: 10 * s, weight: .semibold))
                        .foregroundStyle(index == 0 ? .white : NotchColor.secondaryText)
                    Image(systemName: day.symbolName)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 14 * s))
                        .frame(height: 17 * s)
                    RangeBar(range: forecast.range(of: day))
                        .frame(height: 4 * s)
                        .padding(.horizontal, 6 * s)
                    HStack(spacing: 3 * s) {
                        Text("\(Int(day.high.rounded()))°").foregroundStyle(.white)
                        Text("\(Int(day.low.rounded()))°").foregroundStyle(NotchColor.secondaryText)
                    }
                    .font(.system(size: 11 * s, weight: .semibold))
                    .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6 * s)
                .background(RoundedRectangle(cornerRadius: 10 * s, style: .continuous).fill(Color.white.opacity(index == 0 ? 0.1 : 0.05)))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct RangeBar: View {
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 1), NotchColor.yellow, NotchColor.orange],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geometry.size.height, geometry.size.width * (range.upperBound - range.lowerBound)))
                    .offset(x: geometry.size.width * range.lowerBound)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Weather in Home: now, and the next few hours. Click for the full view.
struct WeatherHomeSection: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        Button { model.open(.weather) } label: {
            VStack(alignment: .leading, spacing: 6 * s) {
                HStack(spacing: 6 * s) {
                    Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor)
                        .font(.system(size: 11 * s, weight: .semibold))
                    Text(model.weather.current?.city ?? "Weather")
                        .font(.system(size: 12 * s, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 9 * s, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                if let forecast = model.weather.forecast {
                    HStack(spacing: 6 * s) {
                        Text(forecast.now.temperatureLabel)
                            .font(.system(size: 26 * s, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Image(systemName: forecast.now.symbolName)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 18 * s))
                    }
                    HStack(spacing: 10 * s) {
                        ForEach(forecast.hours.dropFirst().prefix(4)) { hour in
                            VStack(spacing: 2 * s) {
                                Text(WeatherText.hour(hour.time, zone: forecast.timeZone))
                                    .foregroundStyle(NotchColor.secondaryText)
                                Image(systemName: hour.symbolName).symbolRenderingMode(.multicolor)
                                Text("\(Int(hour.temperature.rounded()))°").foregroundStyle(.white)
                            }
                        }
                    }
                    .font(.system(size: 10 * s, weight: .semibold))
                    .monospacedDigit()
                } else {
                    Text(model.weatherNeedsCity ? "Pick a place" : "Getting the weather…")
                        .font(.system(size: 11 * s, weight: .medium))
                        .foregroundStyle(NotchColor.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(model.weather.current.map { "Weather, \($0.city), \($0.temperatureLabel), \($0.summary)" } ?? "Weather"))
    }
}

/// Labels for the weather views, apart so they're testable.
enum WeatherText {
    /// "14" (24-hour regions) or "2PM", in the place's time zone; with minutes for sunrise/sunset.
    static func hour(_ date: Date, zone: TimeZone, minutes: Bool = false, locale: Locale = .current) -> String {
        var style = Date.FormatStyle(locale: locale, timeZone: zone)
        style = minutes ? style.hour().minute() : style.hour()
        return date.formatted(style)
    }

    static func weekday(_ date: Date, zone: TimeZone, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: zone).weekday(.abbreviated))
    }

    /// "30%" for a real chance of rain, nothing below 20 %.
    static func rain(_ chance: Int?) -> String {
        guard let chance, chance >= 20 else { return "" }
        return "\((chance + 5) / 10 * 10)%"
    }

    static func rainAlert(_ hour: WeatherForecast.Hour, zone: TimeZone) -> String {
        String(localized: "Rain at \(Self.hour(hour.time, zone: zone))")
    }

    static func wind(_ speed: Double, locale: Locale = .current) -> String {
        locale.measurementSystem == .us ? "\(Int(speed.rounded())) mph" : "\(Int(speed.rounded())) km/h"
    }
}
