import SwiftUI
import ServiceManagement

/// Settings panel accessible from the popover.
struct SettingsView: View {
    @Binding var tooQuietThreshold: Double
    @Binding var quietThreshold: Double
    @Binding var goodThreshold: Double
    @Binding var loudThreshold: Double

    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)

            Divider()

            // Threshold settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Level Thresholds (dBFS)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ThresholdSlider(
                    label: "Too Quiet below",
                    value: $tooQuietThreshold,
                    range: -80...(-20),
                    color: .red
                )
                ThresholdSlider(
                    label: "Quiet below",
                    value: $quietThreshold,
                    range: -60...(-10),
                    color: .orange
                )
                ThresholdSlider(
                    label: "Good below",
                    value: $goodThreshold,
                    range: -30...(-3),
                    color: .green
                )
                ThresholdSlider(
                    label: "Loud below",
                    value: $loudThreshold,
                    range: -12...(0),
                    color: .yellow
                )
            }

            Divider()

            // Launch at login
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Divider()

            // Reset
            Button("Reset to Defaults") {
                tooQuietThreshold = -50
                quietThreshold = -40
                goodThreshold = -12
                loudThreshold = -3
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}

struct ThresholdSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .frame(width: 100, alignment: .leading)
            Slider(value: $value, in: range, step: 1)
            Text(String(format: "%.0f", value))
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 30, alignment: .trailing)
        }
    }
}
