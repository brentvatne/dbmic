import XCTest
@testable import dBMicCore

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - LevelThresholds Tests

final class LevelThresholdsTests: XCTestCase {

    func testDefaultValues() {
        let defaults = LevelThresholds.default
        XCTAssertEqual(defaults.tooQuiet, -50)
        XCTAssertEqual(defaults.quiet, -40)
        XCTAssertEqual(defaults.good, -12)
        XCTAssertEqual(defaults.loud, -3)
    }

    func testCustomInitialization() {
        let custom = LevelThresholds(tooQuiet: -60, quiet: -45, good: -15, loud: -5)
        XCTAssertEqual(custom.tooQuiet, -60)
        XCTAssertEqual(custom.quiet, -45)
        XCTAssertEqual(custom.good, -15)
        XCTAssertEqual(custom.loud, -5)
    }

    func testEquatable() {
        let a = LevelThresholds(tooQuiet: -50, quiet: -40, good: -12, loud: -3)
        let b = LevelThresholds.default
        XCTAssertEqual(a, b)

        let c = LevelThresholds(tooQuiet: -55, quiet: -40, good: -12, loud: -3)
        XCTAssertNotEqual(a, c)
    }

    func testCodable() throws {
        let original = LevelThresholds.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LevelThresholds.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}

// MARK: - LevelColors Tests

final class LevelColorsTests: XCTestCase {

    // MARK: color() tests - only available where SwiftUI can be imported

    #if canImport(SwiftUI)
    func testColorTooQuiet() {
        // dB at -55, below tooQuiet threshold (-50) -> red
        let color = LevelColors.color(for: -55)
        XCTAssertEqual(color, .red)
    }

    func testColorQuiet() {
        // dB at -45, between tooQuiet (-50) and quiet (-40) -> orange
        let color = LevelColors.color(for: -45)
        XCTAssertEqual(color, .orange)
    }

    func testColorGood() {
        // dB at -20, between quiet (-40) and good (-12) -> green
        let color = LevelColors.color(for: -20)
        XCTAssertEqual(color, .green)
    }

    func testColorLoud() {
        // dB at -5, between good (-12) and loud (-3) -> yellow
        let color = LevelColors.color(for: -5)
        XCTAssertEqual(color, .yellow)
    }

    func testColorClipping() {
        // dB at -1, above loud (-3) -> red
        let color = LevelColors.color(for: -1)
        XCTAssertEqual(color, .red)
    }

    func testColorAtExactThresholdBoundaries() {
        // At exactly -50 (tooQuiet boundary) -> red (uses <=)
        XCTAssertEqual(LevelColors.color(for: -50), .red)
        // At exactly -40 (quiet boundary) -> orange (uses <=)
        XCTAssertEqual(LevelColors.color(for: -40), .orange)
        // At exactly -12 (good boundary) -> green (uses <=)
        XCTAssertEqual(LevelColors.color(for: -12), .green)
        // At exactly -3 (loud boundary) -> yellow (uses <=)
        XCTAssertEqual(LevelColors.color(for: -3), .yellow)
    }

    func testColorWithCustomThresholds() {
        let custom = LevelThresholds(tooQuiet: -60, quiet: -45, good: -15, loud: -5)
        // -55 is between -60 and -45 with custom -> orange
        XCTAssertEqual(LevelColors.color(for: -55, thresholds: custom), .orange)
        // -50 is between -60 and -45 with custom -> orange
        XCTAssertEqual(LevelColors.color(for: -50, thresholds: custom), .orange)
    }
    #endif

    // MARK: label() tests

    func testLabelSilent() {
        XCTAssertEqual(LevelColors.label(for: -160), "Silent")
        XCTAssertEqual(LevelColors.label(for: -161), "Silent")
    }

    func testLabelTooQuiet() {
        // Between -160 (exclusive) and -50 (inclusive)
        XCTAssertEqual(LevelColors.label(for: -55), "Too Quiet")
        XCTAssertEqual(LevelColors.label(for: -50), "Too Quiet")
    }

    func testLabelQuiet() {
        // Between -50 (exclusive) and -40 (inclusive)
        XCTAssertEqual(LevelColors.label(for: -45), "Quiet")
        XCTAssertEqual(LevelColors.label(for: -40), "Quiet")
    }

    func testLabelGood() {
        // Between -40 (exclusive) and -12 (inclusive)
        XCTAssertEqual(LevelColors.label(for: -20), "Good")
        XCTAssertEqual(LevelColors.label(for: -12), "Good")
    }

    func testLabelLoud() {
        // Between -12 (exclusive) and -3 (inclusive)
        XCTAssertEqual(LevelColors.label(for: -5), "Loud")
        XCTAssertEqual(LevelColors.label(for: -3), "Loud")
    }

    func testLabelClipping() {
        // Above -3
        XCTAssertEqual(LevelColors.label(for: -2), "Clipping!")
        XCTAssertEqual(LevelColors.label(for: 0), "Clipping!")
    }

    func testLabelWithCustomThresholds() {
        let custom = LevelThresholds(tooQuiet: -60, quiet: -45, good: -15, loud: -5)
        XCTAssertEqual(LevelColors.label(for: -55, thresholds: custom), "Quiet")
        XCTAssertEqual(LevelColors.label(for: -50, thresholds: custom), "Quiet")
    }

    // MARK: iconName() tests

    func testIconNameSilent() {
        XCTAssertEqual(LevelColors.iconName(for: -160), "mic.slash")
        XCTAssertEqual(LevelColors.iconName(for: -170), "mic.slash")
    }

    func testIconNameTooQuiet() {
        // Between -160 (exclusive) and tooQuiet (-50 inclusive) -> "mic"
        XCTAssertEqual(LevelColors.iconName(for: -55), "mic")
        XCTAssertEqual(LevelColors.iconName(for: -50), "mic")
    }

    func testIconNameNormal() {
        // Between tooQuiet (-50 exclusive) and good (-12 inclusive) -> "mic.fill"
        XCTAssertEqual(LevelColors.iconName(for: -30), "mic.fill")
        XCTAssertEqual(LevelColors.iconName(for: -12), "mic.fill")
    }

    func testIconNameTooLoud() {
        // Above good (-12) -> "mic.badge.xmark"
        XCTAssertEqual(LevelColors.iconName(for: -5), "mic.badge.xmark")
        XCTAssertEqual(LevelColors.iconName(for: 0), "mic.badge.xmark")
    }

    func testIconNameWithCustomThresholds() {
        let custom = LevelThresholds(tooQuiet: -60, quiet: -45, good: -15, loud: -5)
        // -55 is between tooQuiet (-60) and good (-15) -> "mic.fill"
        XCTAssertEqual(LevelColors.iconName(for: -55, thresholds: custom), "mic.fill")
        // -65 is below tooQuiet (-60) -> "mic"
        XCTAssertEqual(LevelColors.iconName(for: -65, thresholds: custom), "mic")
    }
}

// MARK: - SoundCheckState Tests

final class SoundCheckStateTests: XCTestCase {

    // MARK: Phase transitions

    func testInitialPhaseIsIdle() {
        let state = SoundCheckState()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.verdict)
        XCTAssertNil(state.startTime)
    }

    func testStartTransitionsToRecording() {
        var state = SoundCheckState()
        state.start()
        XCTAssertEqual(state.phase, .recording)
        XCTAssertNotNil(state.startTime)
        XCTAssertNil(state.verdict)
    }

    func testFinishTransitionsToDone() {
        var state = SoundCheckState()
        state.start()
        state.finish()
        XCTAssertEqual(state.phase, .done)
        XCTAssertNotNil(state.verdict)
    }

    func testIdleToRecordingToDone() {
        var state = SoundCheckState()
        XCTAssertEqual(state.phase, .idle)

        state.start()
        XCTAssertEqual(state.phase, .recording)

        // Add some speech samples
        for _ in 0..<20 {
            state.addSample(-25, silenceFloor: -55)
        }

        state.finish()
        XCTAssertEqual(state.phase, .done)
    }

    func testResetGoesBackToIdle() {
        var state = SoundCheckState()
        state.start()
        state.addSample(-20, silenceFloor: -55)
        state.finish()
        XCTAssertEqual(state.phase, .done)

        state.reset()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.verdict)
        XCTAssertNil(state.startTime)
    }

    // MARK: Verdict: no speech detected

    func testVerdictNoSpeechWhenAllSilent() {
        var state = SoundCheckState()
        state.start()

        // Add 100 samples all below the silence floor (-55)
        for _ in 0..<100 {
            state.addSample(-70, silenceFloor: -55)
        }

        state.finish()
        XCTAssertEqual(state.verdict, .noSpeechDetected)
    }

    func testVerdictNoSpeechWhenTooFewSpeechSamples() {
        var state = SoundCheckState()
        state.start()

        // 100 total samples, only 10 above silence floor (10% < 15% threshold)
        for _ in 0..<90 {
            state.addSample(-70, silenceFloor: -55)
        }
        for _ in 0..<10 {
            state.addSample(-30, silenceFloor: -55)
        }

        state.finish()
        XCTAssertEqual(state.verdict, .noSpeechDetected)
    }

    // MARK: Verdict: too quiet

    func testVerdictTooQuiet() {
        var state = SoundCheckState()
        state.start()

        // All speech samples average below -45
        // 80 speech samples at -48 dB, 20 silence samples
        for _ in 0..<80 {
            state.addSample(-48, silenceFloor: -55)
        }
        for _ in 0..<20 {
            state.addSample(-70, silenceFloor: -55)
        }

        state.finish()

        if case .tooQuiet(let avg) = state.verdict {
            XCTAssertEqual(avg, -48, accuracy: 0.1)
        } else {
            XCTFail("Expected tooQuiet verdict, got \(String(describing: state.verdict))")
        }
    }

    // MARK: Verdict: too loud

    func testVerdictTooLoud() {
        var state = SoundCheckState()
        state.start()

        // All speech samples average above -6
        for _ in 0..<80 {
            state.addSample(-3, silenceFloor: -55)
        }
        for _ in 0..<20 {
            state.addSample(-70, silenceFloor: -55)
        }

        state.finish()

        if case .tooLoud(let avg) = state.verdict {
            XCTAssertEqual(avg, -3, accuracy: 0.1)
        } else {
            XCTFail("Expected tooLoud verdict, got \(String(describing: state.verdict))")
        }
    }

    // MARK: Verdict: pass

    func testVerdictPass() {
        var state = SoundCheckState()
        state.start()

        // Speech samples average between -45 and -6
        for _ in 0..<80 {
            state.addSample(-20, silenceFloor: -55)
        }
        for _ in 0..<20 {
            state.addSample(-70, silenceFloor: -55)
        }

        state.finish()

        if case .pass(let avg) = state.verdict {
            XCTAssertEqual(avg, -20, accuracy: 0.1)
        } else {
            XCTFail("Expected pass verdict, got \(String(describing: state.verdict))")
        }
    }

    func testVerdictPassAtBoundaryValues() {
        // Exactly -45 should be pass (boundary: < -45 is tooQuiet)
        var state = SoundCheckState()
        state.start()
        for _ in 0..<100 {
            state.addSample(-45, silenceFloor: -55)
        }
        state.finish()
        if case .pass(let avg) = state.verdict {
            XCTAssertEqual(avg, -45, accuracy: 0.1)
        } else {
            XCTFail("Expected pass verdict at -45, got \(String(describing: state.verdict))")
        }

        // Exactly -6 should be pass (boundary: > -6 is tooLoud)
        var state2 = SoundCheckState()
        state2.start()
        for _ in 0..<100 {
            state2.addSample(-6, silenceFloor: -55)
        }
        state2.finish()
        if case .pass(let avg) = state2.verdict {
            XCTAssertEqual(avg, -6, accuracy: 0.1)
        } else {
            XCTFail("Expected pass verdict at -6, got \(String(describing: state2.verdict))")
        }
    }

    // MARK: Progress calculation

    func testProgressIsZeroWhenIdle() {
        let state = SoundCheckState()
        XCTAssertEqual(state.progress, 0)
    }

    func testProgressIsZeroWhenDone() {
        var state = SoundCheckState()
        state.start()
        for _ in 0..<20 {
            state.addSample(-20, silenceFloor: -55)
        }
        state.finish()
        // After finish, phase is .done, so progress returns 0
        XCTAssertEqual(state.progress, 0)
    }

    func testProgressDuringRecording() {
        var state = SoundCheckState()
        state.duration = 10.0
        // Manually set startTime to 3 seconds ago
        state.start()
        state.startTime = Date().addingTimeInterval(-3)

        let progress = state.progress
        // Should be approximately 0.3 (3 seconds / 10 seconds)
        XCTAssertEqual(progress, 0.3, accuracy: 0.05)
    }

    func testProgressClampedToOne() {
        var state = SoundCheckState()
        state.duration = 5.0
        state.start()
        // Set start time to 10 seconds ago (well past duration)
        state.startTime = Date().addingTimeInterval(-10)

        let progress = state.progress
        XCTAssertEqual(progress, 1.0, accuracy: 0.001)
    }

    // MARK: Edge cases

    func testAddSampleIgnoredWhenNotRecording() {
        var state = SoundCheckState()
        // Phase is idle, addSample should be a no-op
        state.addSample(-20, silenceFloor: -55)

        state.start()
        state.finish()
        // Phase is done, verdict should be noSpeechDetected since no samples were
        // actually counted during recording
        XCTAssertEqual(state.verdict, .noSpeechDetected)
    }

    func testFinishIgnoredWhenNotRecording() {
        var state = SoundCheckState()
        // Calling finish while idle should be a no-op
        state.finish()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.verdict)
    }

    func testDefaultDuration() {
        let state = SoundCheckState()
        XCTAssertEqual(state.duration, 5.0)
    }

    func testSpeechRatioBoundary() {
        // Exactly at the 15% boundary
        var state = SoundCheckState()
        state.start()

        // 100 total samples, 15 speech = 15% -> should be noSpeechDetected (< 0.15 is strict less-than)
        for _ in 0..<85 {
            state.addSample(-70, silenceFloor: -55)
        }
        for _ in 0..<15 {
            state.addSample(-20, silenceFloor: -55)
        }
        state.finish()

        // 15/100 = 0.15 which is NOT < 0.15, so it should proceed to verdict
        if case .pass(let avg) = state.verdict {
            XCTAssertEqual(avg, -20, accuracy: 0.1)
        } else {
            XCTFail("Expected pass verdict at 15% speech ratio, got \(String(describing: state.verdict))")
        }
    }

    func testMixedSpeechLevelsAveraging() {
        var state = SoundCheckState()
        state.start()

        // Mix of speech levels that should average to a passing range
        // 50 samples at -30, 50 samples at -20 -> average = -25
        for _ in 0..<50 {
            state.addSample(-30, silenceFloor: -55)
        }
        for _ in 0..<50 {
            state.addSample(-20, silenceFloor: -55)
        }

        state.finish()

        if case .pass(let avg) = state.verdict {
            XCTAssertEqual(avg, -25, accuracy: 0.1)
        } else {
            XCTFail("Expected pass verdict, got \(String(describing: state.verdict))")
        }
    }
}
