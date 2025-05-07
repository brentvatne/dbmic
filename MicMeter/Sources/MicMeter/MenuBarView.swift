import SwiftUI
import MicMeterCore

/// The view rendered directly in the macOS menu bar via NSHostingView.
/// Shows a colored mic icon in the menu bar. The color indicates the current
/// level category, avoiding constant redraws while staying compact.
struct MenuBarView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    var thresholds: LevelThresholds = .default

    var body: some View {
        let state = currentState
        Image(systemName: state.icon)
            .font(.system(size: 13))
            .foregroundColor(state.color)
            .frame(width: 20)
    }

    private var currentState: (icon: String, color: Color) {
        if !monitor.isMonitoring {
            return ("mic.slash", .secondary)
        }
        if !monitor.isSpeaking {
            return ("mic", .secondary)
        }
        let dB = monitor.decibelLevel
        return (
            LevelColors.iconName(for: dB, thresholds: thresholds),
            LevelColors.color(for: dB, thresholds: thresholds)
        )
    }
}
