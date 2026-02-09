import SwiftUI
import MicMeterCore

/// The view rendered directly in the macOS menu bar via NSHostingView.
/// Shows the current dB level as colored text.
/// When the user is not speaking (silence), the display dims to avoid distraction.
struct MenuBarView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    var thresholds: LevelThresholds = .default

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 11))

            if monitor.isMonitoring {
                Text(formattedDB)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .foregroundColor(foregroundColor)
    }

    private var iconName: String {
        if !monitor.isMonitoring {
            return "mic.slash"
        }
        if !monitor.isSpeaking {
            return "mic"
        }
        return LevelColors.iconName(for: monitor.decibelLevel, thresholds: thresholds)
    }

    private var foregroundColor: Color {
        if !monitor.isMonitoring {
            return .secondary
        }
        if !monitor.isSpeaking {
            // Dim when silent — no need to draw attention
            return .secondary
        }
        return LevelColors.color(for: monitor.decibelLevel, thresholds: thresholds)
    }

    private var formattedDB: String {
        let level = monitor.decibelLevel
        if level <= -100 {
            return "-\u{221E}" // −∞
        }
        return String(format: "%0.f", level)
    }
}
