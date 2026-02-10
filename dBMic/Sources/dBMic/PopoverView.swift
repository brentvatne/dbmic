import SwiftUI
import dBMicCore

/// The popover shown when clicking the menu bar item.
/// Displays a detailed level meter, device info, and controls.
struct PopoverView: View {
    @ObservedObject var monitor: AudioLevelMonitor
    @AppStorage("tooQuietThreshold") var tooQuietThreshold: Double = -50
    @AppStorage("quietThreshold") var quietThreshold: Double = -40
    @AppStorage("goodThreshold") var goodThreshold: Double = -12
    @AppStorage("loudThreshold") var loudThreshold: Double = -3

    @State private var showingSettings = false
    @State private var showingSoundCheck = false
    @State private var showingPeakInfo = false
    @State private var showingLevelInfo = false

    var thresholds: LevelThresholds {
        LevelThresholds(
            tooQuiet: Float(tooQuietThreshold),
            quiet: Float(quietThreshold),
            good: Float(goodThreshold),
            loud: Float(loudThreshold)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Level meter
            levelMeterSection
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

            Divider()

            // History graph
            HistoryGraphView(history: monitor.levelHistory, thresholds: thresholds)
                .frame(height: 70)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

            Divider()

            // Device info
            deviceSection
                .padding(.vertical, 8)
                .padding(.horizontal, 16)

            Divider()

            // Controls
            controlsSection
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        .frame(width: 280)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Text("dBMic")
                .font(.headline)
            Spacer()
            Group {
                if monitor.isSpeaking {
                    levelPill(
                        LevelColors.label(for: monitor.decibelLevel, thresholds: thresholds),
                        color: LevelColors.color(for: monitor.decibelLevel, thresholds: thresholds),
                        fixedWidth: 60,
                        fontSize: 10
                    )
                } else if monitor.isMonitoring {
                    levelPill("Silent", color: .gray, fixedWidth: 60, fontSize: 10)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var levelMeterSection: some View {
        VStack(spacing: 8) {
            // Large dB readout
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(formattedDB)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        monitor.isSpeaking
                            ? LevelColors.color(for: monitor.decibelLevel, thresholds: thresholds)
                            : .secondary
                    )
                Text("dBFS")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Button {
                    showingLevelInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showingLevelInfo) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("dBFS Level")
                            .font(.headline)
                        Text("dBFS (decibels relative to full scale) measures how loud your mic input is. 0 dBFS is the maximum — anything hitting 0 is clipping.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("For calls and recording, aim for **-20 to -12 dBFS** during normal speech. Below -40 is too quiet; above -3 risks distortion.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 220)
                    .padding()
                }
            }

            // Level bar
            LevelBarView(
                level: monitor.decibelLevel,
                peakLevel: monitor.peakLevel,
                thresholds: thresholds
            )
            .frame(height: 12)

            // Scale labels
            HStack {
                Text("-60")
                Spacer()
                Text("-40")
                Spacer()
                Text("-20")
                Spacer()
                Text("0")
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.secondary)

            // Peak readout
            HStack {
                Text("Peak:")
                    .foregroundColor(.secondary)
                Button {
                    monitor.resetPeak()
                } label: {
                    levelPill(
                        String(format: "%.1f dBFS", monitor.peakLevel),
                        color: LevelColors.color(for: monitor.peakLevel, thresholds: thresholds),
                        fixedWidth: 72
                    )
                }
                .buttonStyle(.borderless)
                Button {
                    showingPeakInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showingPeakInfo) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Peak Level")
                            .font(.headline)
                        Text("The highest volume level recorded since monitoring started. Useful for checking if your mic clips (hits 0 dBFS) during calls or recordings.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 200)
                    .padding()
                }
                Spacer()
            }
            .font(.system(size: 11))
        }
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
                Text(monitor.inputDeviceName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            if let error = monitor.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                    Text(error)
                        .font(.system(size: 10))
                }
                .foregroundColor(.red)
            }
        }
    }

    private var controlsSection: some View {
        HStack {
            controlButton(
                monitor.isMonitoring ? "Pause" : "Resume",
                systemImage: monitor.isMonitoring ? "pause.fill" : "play.fill"
            ) {
                if monitor.isMonitoring {
                    monitor.stopMonitoring()
                } else {
                    monitor.startMonitoring()
                }
            }

            Spacer()

            controlButton("Test", systemImage: "waveform") {
                showingSoundCheck.toggle()
            }
            .popover(isPresented: $showingSoundCheck) {
                SoundCheckView(monitor: monitor)
            }

            Spacer()

            controlButton("Configure", systemImage: "gear") {
                showingSettings.toggle()
            }
            .popover(isPresented: $showingSettings) {
                SettingsView(
                    tooQuietThreshold: $tooQuietThreshold,
                    quietThreshold: $quietThreshold,
                    goodThreshold: $goodThreshold,
                    loudThreshold: $loudThreshold
                )
            }

            Spacer()

            controlButton("Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func controlButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(width: 50)
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Pill Badge

    private func levelPill(_ text: String, color: Color, fixedWidth: CGFloat? = nil, fontSize: CGFloat = 11) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundColor(pillTextColor(for: color))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: fixedWidth)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
    }

    private func pillTextColor(for bg: Color) -> Color {
        bg == .yellow ? .black : .white
    }

    // MARK: - Helpers

    private var formattedDB: String {
        if !monitor.isMonitoring {
            return "--"
        }
        let level = monitor.decibelLevel
        if level <= -100 {
            return "-\u{221E}"
        }
        return String(format: "%.0f", level)
    }
}

// MARK: - Level Bar

/// A horizontal level meter bar with color zones and a peak indicator.
struct LevelBarView: View {
    let level: Float
    let peakLevel: Float
    let thresholds: LevelThresholds

    /// Maps dBFS value to a 0...1 fraction for display.
    private func fraction(for dB: Float) -> CGFloat {
        let minDB: Float = -60
        let maxDB: Float = 0
        let clamped = max(min(dB, maxDB), minDB)
        return CGFloat((clamped - minDB) / (maxDB - minDB))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.1))

                // Colored level fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(LevelColors.color(for: level, thresholds: thresholds))
                    .frame(width: geo.size.width * fraction(for: level))
                    .animation(.linear(duration: 0.05), value: level)

                // Peak indicator line
                if peakLevel > -60 {
                    Rectangle()
                        .fill(LevelColors.color(for: peakLevel, thresholds: thresholds).opacity(0.8))
                        .frame(width: 2)
                        .offset(x: geo.size.width * fraction(for: peakLevel) - 1)
                        .animation(.linear(duration: 0.05), value: peakLevel)
                }

                // Zone markers
                ForEach([-40, -20, -6] as [Float], id: \.self) { marker in
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(width: 1)
                        .offset(x: geo.size.width * fraction(for: marker))
                }
            }
        }
    }
}
