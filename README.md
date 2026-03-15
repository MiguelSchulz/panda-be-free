<p align="center">
  <img src="Resources/screenshots/logo.png" width="128" alt="PandaBeFree logo">
</p>

<h1 align="center">PandaBeFree</h1>

<p align="center">
  A free, open-source 3D printer dashboard for iOS.<br>
  Connects directly to your Bambu Lab printer via MQTT on your local network — no cloud, no server, no subscription.
</p>

<p align="center">
  <a href="https://testflight.apple.com/join/Tb7w9szg">
    <img src="https://img.shields.io/badge/TestFlight-Join%20Beta-blue?style=for-the-badge&logo=apple" alt="Join TestFlight Beta">
  </a>
</p>

<p align="center">
  <a href="https://github.com/MiguelSchulz/panda-be-free/actions/workflows/ci.yml">
    <img src="https://github.com/MiguelSchulz/panda-be-free/actions/workflows/ci.yml/badge.svg" alt="CI">
  </a>
  &nbsp;
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0">
  &nbsp;
  <img src="https://img.shields.io/badge/iOS-18+-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 18+">
  &nbsp;
  <img src="https://img.shields.io/github/license/MiguelSchulz/panda-be-free?style=flat-square" alt="License">
  &nbsp;
  <a href="https://github.com/sponsors/MiguelSchulz">
    <img src="https://img.shields.io/badge/Sponsor-EA4AAA?style=flat-square&logo=githubsponsors&logoColor=white" alt="Sponsor">
  </a>
</p>

---

<p align="center">
  <img src="Resources/screenshots/onboarding.PNG" width="200" alt="Onboarding">
  &nbsp;
  <img src="Resources/screenshots/dashboard.PNG" width="200" alt="Dashboard">
  &nbsp;
  <img src="Resources/screenshots/controls.PNG" width="200" alt="Controls">
  &nbsp;
  <img src="Resources/screenshots/widgets.png" width="200" alt="Widgets">
</p>

---

## Features

- **Live Dashboard** — real-time print progress, temperatures, fan speeds, layer info, and ETA
- **Camera Streaming** — live camera feed with fullscreen and zoom support
- **AMS Monitoring** — filament status, colors, material types, and drying control
- **Printer Controls** — pause, resume, stop, speed profiles, light toggle, temperature adjustment, fan control, and airduct mode
- **Home Screen Widgets** — camera snapshot, print progress, and AMS status at a glance
- **Fully Local** — your data never leaves your network
- **Live Activity** — print progress on your Lock Screen and Dynamic Island with an auto-filling progress bar, countdown timer, and estimated finish time
- **Notifications** — get notified when your print or AMS drying finishes
- **Localized** — available in English and German

## Requirements

- **iPhone** with iOS 18+
- **Bambu Lab printer** on the same local network

---

## Notifications & Live Activity

PandaBeFree supports **local notifications** (print finished, drying finished) and a **Live Activity** that shows print progress on your Lock Screen and Dynamic Island. Since the app connects directly to your printer over LAN — no server involved — all of this works locally.

### How it works

- **While the app is open**, it receives real-time data from your printer via MQTT and keeps everything up to date.
- **In the background**, iOS doesn't allow persistent connections. The app estimates completion times, schedules notifications, and updates the Live Activity whenever it gets a chance to run — when you open it, when a widget refreshes, or during occasional background tasks.
- **The Live Activity** shows an auto-filling progress bar, a countdown timer, and an estimated finish time. The progress bar and countdown continue smoothly even without updates, based on the last known state. After about 2 minutes without fresh data, a "stale" indicator appears.

### Tips for the best experience

- **Add at least one Home Screen widget.** Widgets give iOS more reasons to grant the app background execution time — every widget refresh also updates the Live Activity and notification estimates.
- **Open the app regularly** during a print, even briefly. Every time the app connects to your printer, the Live Activity, countdown, and notifications are refreshed with accurate data.
- **Use the app for printer actions** (pause, resume, speed changes, etc.) instead of other tools — each interaction is an opportunity to sync fresh data.

### Why not a server?

Server-pushed updates (via APNs) would keep everything perfectly in sync, but they're not compatible with the open-source, local-only model:

- A **centralized server** would need access to each user's local network and printer credentials — breaking the local-only model.
- A **self-hosted server** solves LAN access but can't send APNs notifications without the developer's `.p8` key, a secret tied to the Apple Developer account that cannot be published.

The local approach means updates depend on when iOS gives the app execution time, but it keeps your data entirely on your network with zero external dependencies.

---

## Upcoming

- **Multi-printer support** — monitor and control multiple printers from a single dashboard
- **Broader printer testing** — currently developed and tested on a **P2S** only. Other Bambu Lab models should work but haven't been verified — feedback from owners of other printers is very welcome
- **Android** — if there's enough interest from the community

---

## Support

PandaBeFree is a lot of fun, but also a lot of work. If you enjoy using it, please consider sponsoring the project. This helps a lot to cover costs like Apple Developer Membership, LLM Tokens for faster development, coffee to keep me running, and filament😉

[![Sponsor](https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/MiguelSchulz)

---

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/miguelschulz/PandaBeFree.git
   cd PandaBeFree
   ```

2. Open the Xcode project:
   ```bash
   open PandaBeFree.xcodeproj
   ```

3. Set up signing — copy the example config and fill in your Team ID and bundle identifier:
   ```bash
   cp Configuration/LocalSigning.xcconfig.example Configuration/LocalSigning.xcconfig
   ```
   Edit `LocalSigning.xcconfig` with your values. This file is gitignored.

4. Build and run on your iPhone.

5. Follow the in-app onboarding to enter your printer's IP address and access code (found on the printer's touchscreen under Network settings).

---


## License

MIT — see [LICENSE](LICENSE) for details.

