# MicMeter

A macOS menu bar app that shows the real-time decibel level of your system audio input (microphone). Built for people who frequently get told "you're too quiet" on calls.

## Features

- **Live dB display in menu bar** — always visible, color-coded (red = too quiet/clipping, orange = quiet, green = good, yellow = loud)
- **Detailed popover** — click for a larger level meter with peak indicator, device info, and controls
- **Auto-detects input device changes** — seamlessly switches when you plug in a different mic or change system input
- **Configurable thresholds** — adjust the dB ranges for each color zone to match your mic and preferences
- **Launch at Login** — optional, via macOS native `SMAppService`
- **Menu-bar-only** — no Dock icon, no window, just the info you need

## Screenshot

```
Menu bar:  [mic.fill -28]     ← green, good level
           [mic     -52]     ← red, too quiet!
```

## Requirements

- macOS 13 (Ventura) or later
- Microphone permission

## Building

Open the project in Xcode or build from the command line:

```bash
cd MicMeter
swift build
```

To run:

```bash
swift run
# or open in Xcode and hit Run
```

For a release build:

```bash
swift build -c release
```

The built binary will be in `.build/release/MicMeter`.

## How It Works

1. **AVAudioEngine** installs a tap on the system's default audio input node
2. Each audio buffer is processed using **Accelerate** (`vDSP_rmsqv`) for efficient RMS calculation
3. RMS is converted to **dBFS** (decibels relative to full scale): `20 * log10(rms)`
4. An exponential moving average smooths the readings
5. The level is displayed in the menu bar via **NSStatusItem** with an **NSHostingView** wrapping a SwiftUI view
6. **Core Audio** listeners detect when the default input device changes and automatically restart monitoring

## dB Ranges (defaults, configurable)

| Range | Color | Meaning |
|-------|-------|---------|
| Below -50 dBFS | Red | Too quiet — turn up your mic gain |
| -50 to -40 dBFS | Orange | Quiet — might want to speak up or adjust gain |
| -40 to -12 dBFS | Green | Good — you sound great |
| -12 to -3 dBFS | Yellow | Loud — getting hot |
| Above -3 dBFS | Red | Clipping risk — turn it down |

## Project Structure

```
MicMeter/
├── Package.swift
├── Sources/MicMeter/
│   ├── MicMeterApp.swift          # App entry point
│   ├── AppDelegate.swift          # NSStatusItem + popover management
│   ├── AudioLevelMonitor.swift    # AVAudioEngine + Accelerate audio processing
│   ├── LevelColors.swift          # dB → color/label mapping + thresholds
│   ├── MenuBarView.swift          # SwiftUI view rendered in menu bar
│   ├── PopoverView.swift          # Detailed level meter popover
│   ├── PermissionView.swift       # Microphone permission request UI
│   ├── SettingsView.swift         # Threshold + launch-at-login settings
│   ├── Info.plist                 # LSUIElement, mic usage description
│   └── MicMeter.entitlements      # Audio input entitlement
└── Resources/
```

## License

MIT
