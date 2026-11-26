import Foundation

/// When a too-long lyric line slides over to show its end. It reads the start for a little under
/// half the line, then glides across in one short move: a slow crawl would keep SwiftUI redrawing
/// the notch every frame for the whole line.
public enum LyricsScroll {
    public static let glide: Double = 0.5

    public static func delay(lineSeconds: Double) -> Double {
        min(max((lineSeconds - glide) * 0.45, 0.7), 4)
    }
}
