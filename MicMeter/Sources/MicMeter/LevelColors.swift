import SwiftUI

/// Maps dB levels to colors and labels based on configurable thresholds.
struct LevelColors {
    /// Returns a color representing the current dB level.
    /// - Parameter dB: The current level in dBFS
    /// - Parameter thresholds: The threshold configuration
    static func color(for dB: Float, thresholds: LevelThresholds = .default) -> Color {
        if dB <= thresholds.tooQuiet {
            return .red
        } else if dB <= thresholds.quiet {
            return .orange
        } else if dB <= thresholds.good {
            return .green
        } else if dB <= thresholds.loud {
            return .yellow
        } else {
            return .red
        }
    }

    /// Returns a human-readable label for the current level.
    static func label(for dB: Float, thresholds: LevelThresholds = .default) -> String {
        if dB <= -160 {
            return "Silent"
        } else if dB <= thresholds.tooQuiet {
            return "Too Quiet"
        } else if dB <= thresholds.quiet {
            return "Quiet"
        } else if dB <= thresholds.good {
            return "Good"
        } else if dB <= thresholds.loud {
            return "Loud"
        } else {
            return "Clipping!"
        }
    }

    /// Returns an SF Symbol name for the current level.
    static func iconName(for dB: Float, thresholds: LevelThresholds = .default) -> String {
        if dB <= -160 {
            return "mic.slash"
        } else if dB <= thresholds.tooQuiet {
            return "mic"
        } else if dB <= thresholds.good {
            return "mic.fill"
        } else {
            return "mic.badge.xmark"
        }
    }
}

/// Configurable dB thresholds for level categorization.
struct LevelThresholds: Codable, Equatable {
    /// Below this is "Too Quiet" (red)
    var tooQuiet: Float
    /// Below this is "Quiet" (orange), above tooQuiet
    var quiet: Float
    /// Below this is "Good" (green), above quiet
    var good: Float
    /// Below this is "Loud" (yellow), above good. Above this is "Clipping" (red)
    var loud: Float

    static let `default` = LevelThresholds(
        tooQuiet: -50,
        quiet: -40,
        good: -12,
        loud: -3
    )
}
