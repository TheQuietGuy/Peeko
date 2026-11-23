import CoreGraphics
import Foundation

/// Pip: two eyes that live either side of the camera when nothing else is happening, so the
/// notch reads as a small face. Everything here is pure, so it's tested without a screen.
public enum Pip {
    public enum Mood: Equatable, Sendable {
        /// Open eyes that follow the pointer.
        case awake
        /// The pointer is over the notch: eyes widen.
        case curious
        /// Something good just finished (a timer, an assistant, a download): ^ ^ for a moment.
        case happy
        /// Late at night, or you've been away: eyes closed, a small "z".
        case asleep
    }

    /// How long the happy face stays after something finishes.
    public static let happyDuration: TimeInterval = 4
    /// Away this long and Pip dozes off.
    public static let awayBeforeSleep: TimeInterval = 5 * 60

    /// Hover wins (you're right there), then a fresh celebration, then sleep, then awake.
    /// `keptAwake`: Keep Awake is on, so Pip stays up with the Mac.
    public static func mood(hovering: Bool, celebratedAt: Date?, now: Date, hour: Int, secondsSinceInput: TimeInterval, keptAwake: Bool = false) -> Mood {
        if hovering { return .curious }
        if let celebratedAt, now.timeIntervalSince(celebratedAt) < happyDuration, now >= celebratedAt { return .happy }
        if !keptAwake, (1..<6).contains(hour) || secondsSinceInput >= awayBeforeSleep { return .asleep }
        return .awake
    }

    /// Asleep to awake (or curious): the moment Pip says welcome back.
    public static func isWakingUp(from old: Mood, to new: Mood) -> Bool {
        old == .asleep && (new == .awake || new == .curious)
    }

    /// Where the eyes look, each axis -1…1 in quarter steps, from the pointer's position relative
    /// to the camera. AppKit coordinates (y up). Pointer below the notch looks down; far left
    /// looks left. The steps mean a still (or barely moving) pointer gives the same answer, so
    /// the eyes don't re-animate, and the Mac isn't woken, twice a second for nothing.
    public static func gaze(pointer: CGPoint, camera: CGPoint, screenWidth: CGFloat) -> CGVector {
        guard screenWidth > 0 else { return .zero }
        let dx = (pointer.x - camera.x) / (screenWidth / 2)
        let dy = (camera.y - pointer.y) / 400
        return CGVector(dx: clamp(dx), dy: clamp(dy))
    }

    /// Seconds until the next blink: a little irregular, like a real one, but deterministic per
    /// blink so it's testable. 2.5…6 s.
    public static func blinkInterval(seed: Int) -> TimeInterval {
        let mixed = UInt64(truncatingIfNeeded: seed &* 2_654_435_761) % 1000
        return 2.5 + 3.5 * Double(mixed) / 999
    }

    private static func clamp(_ value: CGFloat) -> CGFloat { (min(1, max(-1, value)) * 4).rounded() / 4 }
}
