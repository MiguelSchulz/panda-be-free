# BambuBeFree

A real-time 3D printer dashboard app for iOS. Connects directly to your Bambu Lab printer via MQTT on your local network — no cloud, no server, no subscription.

```
Bambu Printer ──MQTT (LAN)──> iOS App ──> Dashboard UI + Home Screen Widgets
```

## Features

- **Live Dashboard** — real-time print progress, temperatures, fan speeds, layer info, ETA
- **Camera Streaming** — live camera feed from your printer with fullscreen support
- **AMS Monitoring** — filament status, colors, material types, drying control
- **Printer Controls** — pause/resume/stop, speed profiles, light toggle, temperature adjustment, fan control, airduct mode
- **Home Screen Widgets** — camera snapshot, print progress, and AMS status widgets
- **Fully Local** — communicates directly with your printer over LAN, no cloud or external server needed

## Requirements

- **iPhone** with iOS 18+
- **Bambu Lab printer** on the same local network (X1C, P1S, P1P, A1, A1 Mini, etc.)
- **Xcode 16+** to build from source

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/BambuBeFree.git
   cd BambuBeFree
   ```

2. Open the Xcode project:
   ```bash
   open ios/BambuBeFree.xcodeproj
   ```

3. Select your development team under **Signing & Capabilities** for both the `BambuBeFree` and `BambuBeFreeWidgets` targets.

4. Build and run on your iPhone.

5. Follow the in-app onboarding to enter your printer's IP address and access code (found on the printer's touchscreen under Network settings).

### Custom Signing Configuration (Optional)

To avoid changing project settings directly, copy the example config and fill in your values:

```bash
cp ios/Configuration/LocalSigning.xcconfig.example ios/Configuration/LocalSigning.xcconfig
```

Edit `LocalSigning.xcconfig` with your Team ID and bundle identifier. This file is gitignored.

## Architecture

Swift 6.0 / SwiftUI / MVVM. Three Xcode targets share code via a local Swift Package (`ios/Modules/BambuModules`):

| Target | Description |
|---|---|
| `BambuBeFree` | Main app — dashboard, camera, controls |
| `BambuBeFreeWidgets` | Home screen widgets (camera, print state, AMS) |
| `BambuBeFreeTests` | Unit tests |

| Module | Description |
|---|---|
| `BambuModels` | Data models, MQTT message parsing, shared settings |
| `Networking` | MQTT client (CocoaMQTT), camera snapshot service |
| `BambuUI` | Shared UI components (gauges, progress, AMS tray views) |
| `Onboarding` | Printer setup flow |
| `PrinterControl` | Printer control interface |

## Running Tests

```bash
xcodebuild test \
  -project ios/BambuBeFree.xcodeproj \
  -scheme BambuBeFree \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

148 tests across 9 suites covering MQTT parsing, command generation, state management, and UI view model logic.

## License

MIT — see [LICENSE](LICENSE) for details.
