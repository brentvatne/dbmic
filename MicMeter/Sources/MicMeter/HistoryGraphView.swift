import SwiftUI

/// A sparkline graph showing the last 60 seconds of audio levels.
struct HistoryGraphView: View {
    let history: [Float]
    let thresholds: LevelThresholds

    private let minDB: Float = -60
    private let maxDB: Float = 0

    private func fraction(for dB: Float) -> CGFloat {
        let clamped = max(min(dB, maxDB), minDB)
        return CGFloat((clamped - minDB) / (maxDB - minDB))
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Last 60s")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if let last = history.last, last > -160 {
                    Text(String(format: "%.0f dBFS", last))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.05))

                    // Threshold zone lines
                    thresholdLine(at: thresholds.tooQuiet, in: geo, color: .red)
                    thresholdLine(at: thresholds.quiet, in: geo, color: .orange)
                    thresholdLine(at: thresholds.good, in: geo, color: .green)

                    // Sparkline
                    if history.count >= 2 {
                        sparklinePath(in: geo)
                            .stroke(
                                LinearGradient(
                                    colors: [.red, .orange, .green, .yellow, .red],
                                    startPoint: .bottom,
                                    endPoint: .top
                                ),
                                lineWidth: 1.5
                            )

                        // Fill under the line
                        sparklineFilledPath(in: geo)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.2),
                                        Color.accentColor.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }

            // Time labels
            HStack {
                Text("-60s")
                Spacer()
                Text("-30s")
                Spacer()
                Text("now")
            }
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(Color.secondary.opacity(0.6))
        }
    }

    private func thresholdLine(at dB: Float, in geo: GeometryProxy, color: Color) -> some View {
        let y = geo.size.height * (1 - fraction(for: dB))
        return Rectangle()
            .fill(color.opacity(0.2))
            .frame(height: 1)
            .offset(y: y)
    }

    private func sparklinePath(in geo: GeometryProxy) -> Path {
        Path { path in
            guard history.count >= 2 else { return }
            let stepX = geo.size.width / CGFloat(max(history.count - 1, 1))

            for (i, sample) in history.enumerated() {
                let x = CGFloat(i) * stepX
                let y = geo.size.height * (1 - fraction(for: sample))
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func sparklineFilledPath(in geo: GeometryProxy) -> Path {
        Path { path in
            guard history.count >= 2 else { return }
            let stepX = geo.size.width / CGFloat(max(history.count - 1, 1))

            // Top edge (the sparkline)
            for (i, sample) in history.enumerated() {
                let x = CGFloat(i) * stepX
                let y = geo.size.height * (1 - fraction(for: sample))
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Close down to bottom-right, bottom-left
            let lastX = CGFloat(history.count - 1) * stepX
            path.addLine(to: CGPoint(x: lastX, y: geo.size.height))
            path.addLine(to: CGPoint(x: 0, y: geo.size.height))
            path.closeSubpath()
        }
    }
}
