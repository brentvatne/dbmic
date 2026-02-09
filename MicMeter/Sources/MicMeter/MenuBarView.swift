import SwiftUI

/// The view rendered directly in the macOS menu bar via NSHostingView.
/// Shows the current dB level as colored text.
struct MenuBarView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    var thresholds: LevelThresholds = .default

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: LevelColors.iconName(for: monitor.decibelLevel, thresholds: thresholds))
                .font(.system(size: 11))

            if monitor.isMonitoring {
                Text(formattedDB)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
        .foregroundColor(monitor.isMonitoring
            ? LevelColors.color(for: monitor.decibelLevel, thresholds: thresholds)
            : .secondary
        )
    }

    private var formattedDB: String {
        let level = monitor.decibelLevel
        if level <= -100 {
            return "-\u{221E}" // −∞
        }
        return String(format: "%0.f", level)
    }
}
