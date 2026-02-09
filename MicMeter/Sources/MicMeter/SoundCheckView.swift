import SwiftUI

/// Pre-call sound check UI. Asks the user to speak for 5 seconds, then gives a verdict.
struct SoundCheckView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    @State private var progressTimer: Timer?
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            switch monitor.soundCheck.phase {
            case .idle:
                idleView
            case .recording:
                recordingView
            case .done:
                resultView
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // MARK: - Phases

    private var idleView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            Text("Sound Check")
                .font(.headline)

            Text("Speak at your normal volume for 5 seconds. MicMeter will tell you if your level is good for calls.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                monitor.startSoundCheck()
                startProgressAnimation()
            }) {
                Label("Start Test", systemImage: "mic.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 12) {
            // Animated mic icon
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
                .symbolEffect(.pulse)

            Text("Speak now...")
                .font(.headline)

            Text("Talk at your normal call volume")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Live level during test
            Text(String(format: "%.0f dBFS", monitor.decibelLevel))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(monitor.isSpeaking ? .green : .secondary)

            // Progress bar
            ProgressView(value: animatedProgress)
                .progressViewStyle(.linear)
                .tint(.red)

            Text(String(format: "%.1f seconds remaining", max(0, 5.0 - animatedProgress * 5.0)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var resultView: some View {
        VStack(spacing: 12) {
            if let verdict = monitor.soundCheck.verdict {
                verdictView(verdict)
            }

            Button(action: {
                monitor.soundCheck.reset()
                animatedProgress = 0
            }) {
                Label("Test Again", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    @ViewBuilder
    private func verdictView(_ verdict: SoundCheckState.Verdict) -> some View {
        switch verdict {
        case .pass(let avg):
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("You sound great!")
                .font(.headline)
                .foregroundColor(.green)
            Text(String(format: "Average level: %.0f dBFS", avg))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Your mic level is in the sweet spot for calls.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

        case .tooQuiet(let avg):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("Too quiet!")
                .font(.headline)
                .foregroundColor(.red)
            Text(String(format: "Average level: %.0f dBFS", avg))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Turn up your input gain in System Settings \u{2192} Sound \u{2192} Input, or move closer to your microphone.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

        case .tooLoud(let avg):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            Text("Too loud!")
                .font(.headline)
                .foregroundColor(.yellow)
            Text(String(format: "Average level: %.0f dBFS", avg))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Turn down your input gain or move further from your microphone to avoid distortion.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

        case .noSpeechDetected:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("No speech detected")
                .font(.headline)
                .foregroundColor(.orange)
            Text("Make sure you're speaking into the correct microphone and your input isn't muted.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Animation

    private func startProgressAnimation() {
        animatedProgress = 0
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(monitor.soundCheck.startTime ?? Date())
            animatedProgress = min(elapsed / monitor.soundCheck.duration, 1.0)
            if monitor.soundCheck.phase != .recording {
                timer.invalidate()
                animatedProgress = 1.0
            }
        }
    }
}
