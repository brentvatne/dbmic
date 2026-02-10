import SwiftUI
import dBMicCore

/// The view rendered directly in the macOS menu bar via NSHostingView.
/// Shows a mic icon with a colored status dot. The dot color indicates the
/// current level category.
struct MenuBarView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    var thresholds: LevelThresholds = .default

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: micIcon)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 24)
    }

    private var micIcon: String {
        if !monitor.isMonitoring { return "mic.slash" }
        return "mic.fill"
    }

    private var dotColor: Color {
        if !monitor.isMonitoring { return .secondary }
        if !monitor.isSpeaking { return .secondary }
        return LevelColors.color(for: monitor.decibelLevel, thresholds: thresholds)
    }
}
