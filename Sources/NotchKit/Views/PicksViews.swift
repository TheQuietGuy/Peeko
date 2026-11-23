import SwiftUI

/// Colour Picker: the system magnifier picks a colour anywhere on screen. The newest swatch is
/// big with its codes beside it, one click to copy each; older swatches sit in a row below.
struct ColorsPanelBody: View {
    let model: IslandModel
    @State private var selected: PickedColor?
    @State private var copied: String?
    @Environment(\.notchScale) private var s

    var body: some View {
        let colors = model.picks.colors
        let current = selected.flatMap { colors.contains($0) ? $0 : nil } ?? colors.first
        VStack(alignment: .leading, spacing: 12 * s) {
            HStack(spacing: 12 * s) {
                Button(action: model.pickColor) {
                    Label("Pick", systemImage: "eyedropper.halffull")
                }
                .buttonStyle(QuickActionStyle(tint: Color(red: 0.75, green: 0.45, blue: 1), scale: s, width: 84 * s))
                .help("Click anywhere on screen to pick its colour. Its hex code is copied.")

                if let current {
                    RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
                        .fill(current.color)
                        .frame(width: 44 * s, height: 44 * s)
                        .overlay(RoundedRectangle(cornerRadius: 10 * s, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
                        .accessibilityLabel(Text(current.hex))
                    // The hex is short enough to show; the others are named, their code in the tooltip.
                    ForEach([(current.hex, current.hex), ("RGB", current.rgb), ("HSL", current.hsl), ("SwiftUI", current.swiftUI)], id: \.1) { name, code in
                        CopyChip(text: name, copied: copied == code) { copy(code) }
                            .help("Copy \(code)")
                    }
                } else {
                    Text("Pick a colour from anything on screen: a site, a photo, a design.")
                        .font(.system(size: 12 * s, weight: .medium))
                        .foregroundStyle(NotchColor.secondaryText)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8 * s) {
                ForEach(colors, id: \.self) { color in
                    Button { selected = color } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 22 * s, height: 22 * s)
                            .overlay(Circle().stroke(.white.opacity(color == current ? 0.9 : 0.15), lineWidth: color == current ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(color.hex)
                    .accessibilityLabel(Text(color.hex))
                    .contextMenu {
                        Button("Copy \(color.hex)") { copy(color.hex) }
                        Button("Remove") { model.picks.remove(color) }
                        Button("Clear All") { model.picks.clearColors() }
                    }
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.35, bounce: 0.3), value: colors)
        }
        .padding(.top, 4 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func copy(_ code: String) {
        model.copy(code)
        Haptics.perform(enabled: model.settings.hapticsEnabled)
        withAnimation(.snappy) { copied = code }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copied == code { withAnimation(.snappy) { copied = nil } }
        }
    }
}

private struct CopyChip: View {
    let text: String
    let copied: Bool
    let action: () -> Void
    @Environment(\.notchScale) private var s

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4 * s) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(copied ? NotchColor.green : NotchColor.secondaryText)
                Text(text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 11 * s, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8 * s)
            .frame(height: 28 * s)
            .background(RoundedRectangle(cornerRadius: 8 * s, style: .continuous).fill(Color.white.opacity(copied ? 0.16 : 0.08)))
        }
        .buttonStyle(.plain)
    }
}

/// Countdowns: a card per date, soonest first, with the days left big. "+" adds one in place.
struct CountdownsPanelBody: View {
    let model: IslandModel
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @FocusState private var focused: Bool
    @Environment(\.notchScale) private var s
    @Environment(\.brutal) private var brutal

    var body: some View {
        Group {
            if model.isAddingCountdown {
                form
            } else {
                // Re-reads once a minute, so "Today" turns over at midnight.
                TimelineView(.everyMinute) { context in
                    cards(now: context.date)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear { model.isAddingCountdown = false }
    }

    private func cards(now: Date) -> some View {
        // Scrolls only when the cards don't fit.
        ViewThatFits(in: .horizontal) {
            row(now: now)
            ScrollView(.horizontal, showsIndicators: false) { row(now: now) }
        }
    }

    private func row(now: Date) -> some View {
            HStack(spacing: 10 * s) {
                ForEach(Countdown.ordered(model.picks.countdowns, now: now)) { item in
                    card(item, now: now)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
                Button { startAdding() } label: {
                    VStack(spacing: 6 * s) {
                        Image(systemName: "plus")
                            .font(.system(size: 20 * s, weight: .semibold))
                        Text(model.picks.countdowns.isEmpty ? "Add an exam, deadline or trip" : "Add")
                            .font(.system(size: 11 * s, weight: .medium))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(NotchColor.secondaryText)
                    .frame(width: model.picks.countdowns.isEmpty ? 200 * s : 80 * s, height: 96 * s)
                    .background(RoundedRectangle(cornerRadius: 14 * s, style: .continuous).strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4 * s)
            .animation(.spring(duration: 0.4, bounce: 0.2), value: model.picks.countdowns)
    }

    private func card(_ item: Countdown, now: Date) -> some View {
        let label = item.label(from: now)
        let days = item.daysLeft(from: now)
        let shape = RoundedRectangle(cornerRadius: (brutal ? 8 : 14) * s, style: .continuous)
        let tint = days < 0 ? NotchColor.secondaryText : days <= 3 ? NotchColor.orange : NotchColor.yellow
        return VStack(alignment: .leading, spacing: 2 * s) {
            HStack(alignment: .firstTextBaseline, spacing: 4 * s) {
                Text(label.value)
                    .font(.system(size: 30 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText(countsDown: true))
                Text(label.caption)
                    .font(.system(size: 11 * s, weight: .semibold))
                    .foregroundStyle(NotchColor.secondaryText)
            }
            Text(item.title)
                .font(.system(size: 12 * s, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(item.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                .font(.system(size: 10 * s, weight: .medium))
                .foregroundStyle(NotchColor.secondaryText)
        }
        .padding(12 * s)
        .frame(width: 140 * s, height: 96 * s, alignment: .topLeading)
        .background(shape.fill(brutal ? Color(white: 0.09) : Color.white.opacity(0.07)))
        .overlay { if brutal { shape.stroke(BrutalPalette.edge.opacity(0.85), lineWidth: 1.5 * s) } }
        .background { if brutal { shape.fill(BrutalPalette.shadow).offset(x: 3 * s, y: 3 * s) } }
        .contextMenu {
            Button("Remove", role: .destructive) { model.picks.removeCountdown(item.id) }
        }
        .accessibilityElement(children: .combine)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10 * s) {
            Text("New countdown")
                .font(.system(size: 13 * s, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8 * s) {
                TextField("Name", text: $title, prompt: Text("e.g. Algorithms exam"))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13 * s, weight: .medium))
                    .padding(.horizontal, 10 * s)
                    .frame(width: 200 * s, height: 28 * s)
                    .background(RoundedRectangle(cornerRadius: 8 * s, style: .continuous).fill(Color.white.opacity(0.1)))
                    .focused($focused)
                    .onSubmit(save)
                DatePicker("Date", selection: $date, in: Date.now..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                Button("Add", action: save)
                    .buttonStyle(QuickActionStyle(tint: NotchColor.yellow, scale: s))
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") { model.isAddingCountdown = false }
                    .buttonStyle(QuickActionStyle(tint: .white, scale: s))
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.top, 4 * s)
        .onAppear { focused = true }
    }

    private func startAdding() {
        title = ""
        model.isAddingCountdown = true
    }

    private func save() {
        model.picks.addCountdown(title, date: date)
        Haptics.perform(enabled: model.settings.hapticsEnabled)
        model.isAddingCountdown = false
    }
}

extension PickedColor {
    var color: Color { Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255) }
}
