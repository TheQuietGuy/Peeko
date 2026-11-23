import AppKit
import SwiftUI

/// Pip, drawn over a resting real notch: two small ears grow out of it and each holds an eye,
/// so the camera sits between them like a nose. Pip blinks, follows the pointer, widens its
/// eyes when you hover, smiles for a moment when something finishes, and sleeps at night or
/// when you're away. It never takes clicks; the notch underneath still opens as before.
struct PipLayer: View {
    let model: IslandModel
    /// The real notch, in window coordinates.
    let notch: CGRect
    let scale: CGFloat
    let brutal: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var asleep = false

    var body: some View {
        let ear = (IslandMetrics.pipEar * scale).rounded()
        let flare = IslandMetrics.compactFlare
        let width = notch.width + 2 * ear
        // Twice a second is plenty for a glance; the spring fills in between. Asleep, every
        // few seconds is enough to notice you're back (hovering wakes it at once).
        TimelineView(.periodic(from: .now, by: asleep ? 3 : 0.5)) { context in
            let mood = currentMood(at: context.date)
            let gaze = mood == .awake || mood == .curious ? currentGaze() : .zero
            ZStack {
                IslandShape(topRadius: 0, bottomRadius: min(notch.height * 0.42, 12), flare: flare)
                    .fill(.black)
                    .frame(width: width + 2 * flare, height: notch.height)
                HStack(spacing: 0) {
                    PipEye(mood: mood, gaze: gaze, scale: scale, tint: brutal ? BrutalPalette.edge : .white, reduceMotion: reduceMotion)
                        .frame(width: ear)
                    Color.clear.frame(width: notch.width)
                    PipEye(mood: mood, gaze: gaze, scale: scale, tint: brutal ? BrutalPalette.edge : .white, reduceMotion: reduceMotion, sleeper: true)
                        .frame(width: ear)
                }
                .frame(height: notch.height)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: gaze)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 1), value: mood)
            .onChange(of: mood, initial: true) { old, new in
                asleep = new == .asleep
                // Welcome back: waking up (you returned, or it's morning) earns a smile.
                if Pip.isWakingUp(from: old, to: new) { model.pipWokeUp() }
            }
        }
        .frame(width: width + 2 * flare, height: notch.height)
        .position(x: notch.midX, y: notch.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func currentMood(at now: Date) -> Pip.Mood {
        let away = min(
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved),
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        )
        return Pip.mood(
            hovering: model.isHoveringNotch || model.isHoveringPill,
            celebratedAt: model.pipCelebratedAt,
            now: now,
            hour: Calendar.current.component(.hour, from: now),
            secondsSinceInput: away,
            keptAwake: model.keepAwake.isOn
        )
    }

    private func currentGaze() -> CGVector {
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return .zero }
        let camera = CGPoint(x: screen.frame.midX, y: screen.frame.maxY)
        return Pip.gaze(pointer: pointer, camera: camera, screenWidth: screen.frame.width)
    }
}

/// One eye. Open eyes blink on their own clock; happy eyes are arcs; sleeping eyes are lines,
/// and the right one lets a small "z" drift up.
private struct PipEye: View {
    let mood: Pip.Mood
    let gaze: CGVector
    let scale: CGFloat
    let tint: Color
    let reduceMotion: Bool
    var sleeper = false
    @State private var blinking = false
    @State private var blinkCount = 0

    var body: some View {
        let width = 7.5 * scale
        let height = (mood == .curious ? 13 : 11) * scale
        ZStack {
            switch mood {
            case .happy:
                HappyArc()
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round))
                    .frame(width: width + 2 * scale, height: 4.5 * scale)
            case .asleep:
                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: width + 1 * scale, height: 2 * scale)
                    .offset(y: 2 * scale)
                if sleeper {
                    Text("z")
                        .font(.system(size: 7 * scale, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint.opacity(0.8))
                        .offset(x: 6 * scale, y: -5 * scale)
                }
            case .awake, .curious:
                Capsule()
                    .fill(tint)
                    .frame(width: width, height: blinking ? 1.5 * scale : height)
                    .offset(x: gaze.dx * 2.5 * scale, y: gaze.dy * 1.5 * scale)
            }
        }
        .task(id: mood) { await blinkLoop() }
    }

    /// Both eyes count blinks from the same seeds, so they close together.
    private func blinkLoop() async {
        guard mood == .awake || mood == .curious, !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Pip.blinkInterval(seed: blinkCount)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.06)) { blinking = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeOut(duration: 0.1)) { blinking = false }
            blinkCount += 1
        }
    }
}

/// "^": an upturned arc for a smiling eye.
private struct HappyArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return path
    }
}
