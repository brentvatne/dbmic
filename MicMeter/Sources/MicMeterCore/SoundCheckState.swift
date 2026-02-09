import Foundation

/// State machine for the pre-call sound check feature.
/// Records samples for a fixed duration, then produces a verdict.
public struct SoundCheckState {

    public enum Phase {
        case idle
        case recording
        case done
    }

    public enum Verdict: Equatable {
        case pass(averageDB: Float)
        case tooQuiet(averageDB: Float)
        case tooLoud(averageDB: Float)
        case noSpeechDetected
    }

    public var phase: Phase = .idle
    public var duration: TimeInterval = 5.0
    public var startTime: Date?
    public var verdict: Verdict?

    /// Progress from 0 to 1 during recording.
    public var progress: Double {
        guard phase == .recording, let start = startTime else { return 0 }
        return min(Date().timeIntervalSince(start) / duration, 1.0)
    }

    // Private accumulators
    private var speechSamples: [Float] = []
    private var totalSamples = 0
    private var peakSample: Float = -160.0

    public init() {}

    public mutating func start() {
        phase = .recording
        startTime = Date()
        verdict = nil
        speechSamples = []
        totalSamples = 0
        peakSample = -160.0
    }

    public mutating func addSample(_ dB: Float, silenceFloor: Float) {
        guard phase == .recording else { return }
        totalSamples += 1
        if dB > peakSample { peakSample = dB }
        // Only count samples where the user is actually speaking
        if dB > silenceFloor {
            speechSamples.append(dB)
        }
    }

    public mutating func finish() {
        guard phase == .recording else { return }
        phase = .done

        // Need at least 20% of samples to be speech to consider it valid
        let speechRatio = totalSamples > 0
            ? Float(speechSamples.count) / Float(totalSamples)
            : 0

        if speechRatio < 0.15 {
            verdict = .noSpeechDetected
            return
        }

        let avgSpeechDB = speechSamples.reduce(0, +) / Float(speechSamples.count)

        if avgSpeechDB < -45 {
            verdict = .tooQuiet(averageDB: avgSpeechDB)
        } else if avgSpeechDB > -6 {
            verdict = .tooLoud(averageDB: avgSpeechDB)
        } else {
            verdict = .pass(averageDB: avgSpeechDB)
        }
    }

    public mutating func reset() {
        self = SoundCheckState()
    }
}
