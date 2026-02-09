# MicMeter

A macOS menu bar app that monitors your microphone level in real time. Built for people who frequently get told "you're too quiet" on calls.

## Features

- **Colored mic icon in menu bar** — green (good), orange (quiet), yellow (loud), red (too quiet or clipping)
- **Detailed popover** — click for a live dB meter, peak indicator, 60-second history graph, and device info
- **Sound check** — 5-second pre-call test with a pass/fail verdict
- **Voice activity detection** — icon dims when you're not speaking
- **Auto-detects input device changes** — seamlessly switches when you change mics
- **Configurable thresholds** — adjust dB ranges for each color zone
- **Menu-bar-only** — no Dock icon, no window

## Requirements

- macOS 14 (Sonoma) or later
- Microphone permission

## Building

```bash
cd MicMeter
swift build
swift run
# or open in Xcode and hit Run
```

## How It Works

1. **AVAudioEngine** taps the default audio input
2. Each buffer is processed with **Accelerate** (`vDSP_rmsqv`) for RMS calculation
3. RMS converts to **dBFS**: `20 * log10(rms)`
4. Exponential moving average smooths the readings
5. A SwiftUI view in **NSStatusItem** shows a colored mic icon
6. **Core Audio** listeners detect input device changes and restart monitoring

## dB Ranges (defaults, configurable)

| Range | Color | Meaning |
|-------|-------|---------|
| Below -50 dBFS | Red | Too quiet |
| -50 to -40 dBFS | Orange | Quiet |
| -40 to -12 dBFS | Green | Good |
| -12 to -3 dBFS | Yellow | Loud |
| Above -3 dBFS | Red | Clipping |

## License

MIT
