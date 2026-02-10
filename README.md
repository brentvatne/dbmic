# dBMic

A macOS menu bar app that monitors your microphone level in real time. Built for people who frequently get told "you're too quiet" on calls.

## Features

- **Mic icon + colored status dot in menu bar** — green (good), orange (quiet), yellow (loud), red (too quiet or clipping)
- **Detailed popover** — click for a live dB meter, peak indicator, 60-second history graph, and device info
- **Sound check** — 5-second pre-call test with a pass/fail verdict
- **Voice activity detection** — dot dims when you're not speaking
- **Auto-detects input device changes** — seamlessly switches when you change mics
- **Configurable thresholds** — adjust dB ranges for each color zone
- **Menu-bar-only** — no Dock icon, no window

## Requirements

- macOS 14 (Sonoma) or later
- Microphone permission

## Building

```bash
cd dBMic
swift build
swift run
# or open in Xcode and hit Run
```

## How It Works

1. **AVAudioEngine** taps the default audio input
2. Each buffer is processed with **Accelerate** (`vDSP_rmsqv`) for RMS calculation
3. RMS converts to **dBFS**: `20 * log10(rms)`
4. Exponential moving average smooths the readings
5. A SwiftUI view in **NSStatusItem** shows a mic icon with a colored status dot
6. **Core Audio** listeners detect input device changes and restart monitoring

## dB Ranges (defaults, configurable)

| Range | Color | Meaning |
|-------|-------|---------|
| Below -50 dBFS | Red | Too quiet |
| -50 to -40 dBFS | Orange | Quiet |
| -40 to -12 dBFS | Green | Good |
| -12 to -3 dBFS | Yellow | Loud |
| Above -3 dBFS | Red | Clipping |

## Releasing

### Prerequisites

- Apple Developer ID certificate (managed via [Fastlane Match](https://docs.fastlane.tools/actions/match/))
- Apple ID with app-specific password for notarization
- Ruby 3.2+ and Bundler (for Fastlane)

### Setup

1. Copy the environment template and fill in your values:

   ```bash
   cd dBMic
   cp .env.example .env
   # Edit .env with your signing identity, Apple ID, etc.
   ```

2. Install Fastlane and fetch your signing certificate:

   ```bash
   cd dBMic
   bundle install
   bundle exec fastlane match developer_id --readonly
   ```

   This clones the encrypted certificates from the private match repo and installs them into your keychain. You'll need SSH access to that repo and the `MATCH_PASSWORD` from `.env`.

### Local Release

Build a signed, notarized DMG locally:

```bash
cd dBMic
./scripts/release-local.sh
```

This sources `.env`, builds a universal binary (arm64 + x86_64), signs it, submits for notarization, staples the ticket, and creates `build/dBMic.dmg`.

### CI Release (GitHub Actions)

Pushing a version tag triggers the release workflow automatically:

```bash
git tag v1.0.0
git push --tags
```

The CI pipeline (`.github/workflows/ci.yml`) will:

1. Build and run tests
2. Install the signing certificate via Fastlane Match (using an SSH deploy key)
3. Build, sign, and notarize the app via Fastlane
4. Create a GitHub Release with the DMG attached

#### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `MATCH_DEPLOY_KEY` | SSH private key with access to the certificates repo |
| `MATCH_PASSWORD` | Passphrase for decrypting the match certificate store |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/bundle-app.sh` | Build universal binary and assemble `.app` bundle (optionally sign with `--sign`) |
| `scripts/create-dmg.sh` | Create DMG from `build/dBMic.app` |
| `scripts/release-local.sh` | Full local release: build, sign, notarize, DMG |
| `scripts/setup-certs.sh` | Fetch signing certificate via Fastlane Match |

## License

MIT
