import Foundation
import Testing
@testable import NotchKit

@MainActor
@Suite("Audio spectrum and FFT analysis")
struct AudioSpectrumTests {
    private func sine(_ frequency: Double, amplitude: Float = 0.5, count: Int = 2048, sampleRate: Double = 48000) -> [Float] {
        (0..<count).map { amplitude * Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) }
    }

    @Test func computeBandsReturnsSilenceWhenBufferTooSmall() {
        let bands = FFTProcessor.computeBands(samples: [Float](repeating: 0.1, count: 8))
        #expect(bands.count == FFTProcessor.barBands.count)
        #expect(bands.allSatisfy { $0 == 0 })
    }

    @Test func eachToneLightsItsOwnBar() {
        for (index, frequency) in [63.0, 160, 420, 1200, 3200, 9000].enumerated() {
            let bands = FFTProcessor.computeBands(samples: sine(frequency))
            #expect(bands.indices.max { bands[$0] < bands[$1] } == index, "\(frequency) Hz")
            #expect(bands[index] > 0.5)
        }
    }

    @Test func silenceIsAnEmptyBarAndLoudIsFull() {
        #expect(FFTProcessor.computeBands(samples: [Float](repeating: 0, count: 1024)).allSatisfy { $0 == 0 })
        #expect(FFTProcessor.computeBands(samples: sine(100, amplitude: 1))[0] > 0.9)
        #expect(FFTProcessor.computeBands(samples: sine(100, amplitude: 0.01))[0] < FFTProcessor.computeBands(samples: sine(100))[0])
    }

    @Test func barsRiseFastAndFallGently() {
        let analyzer = AudioSpectrumAnalyzer()
        analyzer.update(levels: [1, 1, 1, 1])
        #expect(analyzer.isCapturing)
        let risen = analyzer.bands[0]
        #expect(risen > 0.6)
        analyzer.update(levels: [0.1, 0.1, 0.1, 0.1])
        #expect(analyzer.bands[0] < risen)
        #expect(analyzer.bands[0] > 0.3, "falls in steps, not at once")
        analyzer.reset()
        #expect(analyzer.bands.allSatisfy { $0 == 0 })
        #expect(!analyzer.isCapturing)
    }

    @Test func lastingSilenceHandsTheBarsBack() {
        // A refused macOS prompt means the tap hears only silence.
        let analyzer = AudioSpectrumAnalyzer()
        let start = Date()
        analyzer.update(levels: [0.5, 0.5, 0.5, 0.5], now: start)
        analyzer.update(levels: [0, 0, 0, 0], now: start.addingTimeInterval(0.5))
        #expect(analyzer.isCapturing, "a short pause in the music")
        analyzer.update(levels: [0, 0, 0, 0], now: start.addingTimeInterval(3))
        #expect(!analyzer.isCapturing)
        analyzer.update(levels: [0.5, 0.5, 0.5, 0.5], now: start.addingTimeInterval(4))
        #expect(analyzer.isCapturing)
    }

    @Test func loudSongsStillPumpWithTheBeat() {
        // A heavily mastered song never drops far below full scale; its kicks must still show.
        let analyzer = AudioSpectrumAnalyzer()
        var lows: [Double] = []
        var highs: [Double] = []
        for beat in 0..<40 {
            // A kick, then the rest of half a second (120 bpm) about 12 dB quieter.
            analyzer.update(levels: Array(repeating: 0.95, count: 4))
            if beat > 2 { highs.append(analyzer.bands[0]) }
            for _ in 0..<14 { analyzer.update(levels: Array(repeating: 0.7, count: 4)) }
            if beat > 2 { lows.append(analyzer.bands[0]) }
        }
        #expect(highs.min()! > 0.75)
        #expect(lows.max()! < 0.45, "between kicks the bar drops well down")
    }

    @Test func quietPassagesFillTheBarsAgain() {
        let analyzer = AudioSpectrumAnalyzer()
        analyzer.update(levels: [1, 1, 1, 1])
        for _ in 0..<300 { analyzer.update(levels: [0.6, 0.6, 0.6, 0.6]) }  // ten seconds
        #expect(analyzer.bands[0] > 0.9)
    }

    @Test func compactMusicMakesRoomForALineOfLyrics() {
        let engine = LayoutEngine(screen: .sample, appearance: .standard)
        let music = IslandPresentation.compact(primary: .nowPlaying, secondary: nil)
        let plain = engine.layout(for: music, home: HomeContent(), hovering: false).pill
        let sung = engine.layout(for: music, home: HomeContent(hasLyrics: true), hovering: false).pill
        #expect(sung.height == plain.height + (IslandMetrics.compactLyrics * engine.scale).rounded())
        #expect(sung.width == plain.width + 2 * (IslandMetrics.compactLyricsEar * engine.scale).rounded(), "wider for the words")
        #expect(sung.midX == plain.midX, "still centred on the camera")
        let timer = IslandPresentation.compact(primary: .timer, secondary: nil)
        #expect(engine.layout(for: timer, home: HomeContent(hasLyrics: true), hovering: false).pill.height
            == engine.layout(for: timer, home: HomeContent(), hovering: false).pill.height)
    }

    @Test func onlyMusicViewsTakeTheSongsColour() {
        #expect(IslandPresentation.compact(primary: .nowPlaying, secondary: .timer).showsMusic)
        #expect(IslandPresentation.expanded(.nowPlaying).showsMusic)
        #expect(!IslandPresentation.compact(primary: .timer, secondary: .nowPlaying).showsMusic)
        #expect(!IslandPresentation.idle.showsMusic)
    }

    @Test func lyricsRedrawExactlyWhenEachLineStarts() throws {
        let lyrics = try #require(SyncedLyrics(lrc: "[00:01.00]one\n[00:05.00]two\n[00:09.00]three"))
        let now = Date(timeIntervalSince1970: 1000)
        let starts = lyrics.upcomingStarts(after: 3, rate: 1, now: now)
        #expect(starts == [now.addingTimeInterval(2), now.addingTimeInterval(6)])
        #expect(lyrics.upcomingStarts(after: 3, rate: 2, now: now).first == now.addingTimeInterval(1), "faster playback, sooner")
        #expect(lyrics.upcomingStarts(after: 10, rate: 1, now: now).isEmpty)
    }

    @Test func longLyricLinesGlideOncePartwayThrough() throws {
        #expect(abs(LyricsScroll.delay(lineSeconds: 5) - 2.025) < 1e-9, "a little under half the line")
        #expect(LyricsScroll.delay(lineSeconds: 1) == 0.7, "never before the start can be read")
        #expect(LyricsScroll.delay(lineSeconds: 30) == 4, "a long held note doesn't hide the end for long")
        let lyrics = try #require(SyncedLyrics(lrc: "[00:01.00]one\n[00:04.50]two"))
        #expect(lyrics.duration(of: 0) == 3.5)
        #expect(lyrics.duration(of: 1) == 4)
        #expect(lyrics.duration(of: 9) == 0)
    }
}
