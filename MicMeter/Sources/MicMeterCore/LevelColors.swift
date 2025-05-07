#if canImport(SwiftUI)
import SwiftUI
#endif

/// Maps dB levels to colors and labels based on configurable thresholds.
public struct LevelColors {
    #if canImport(SwiftUI)
    /// Returns a color representing the current dB level.
    /// - Parameter dB: The current level in dBFS
    /// - Parameter thresholds: The threshold configuration
    public static func color(for dB: Float, thresholds: LevelThresholds = .default) -> Color {
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
    #endif

    /// Returns a human-readable label for the current level.
    public static func label(for dB: Float, thresholds: LevelThresholds = .default) -> String {
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
    public static func iconName(for dB: Float, thresholds: LevelThresholds = .default) -> String {
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
public struct LevelThresholds: Codable, Equatable {
    /// Below this is "Too Quiet" (red)
    public var tooQuiet: Float
    /// Below this is "Quiet" (orange), above tooQuiet
    public var quiet: Float
    /// Below this is "Good" (green), above quiet
    public var good: Float
    /// Below this is "Loud" (yellow), above good. Above this is "Clipping" (red)
    public var loud: Float

    public init(tooQuiet: Float, quiet: Float, good: Float, loud: Float) {
        self.tooQuiet = tooQuiet
        self.quiet = quiet
        self.good = good
        self.loud = loud
    }

    public static let `default` = LevelThresholds(
        tooQuiet: -50,
        quiet: -40,
        good: -12,
        loud: -3
    )
}
