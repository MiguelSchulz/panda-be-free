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
  &nbsp;
  <a href="https://github.com/sponsors/MiguelSchulz">
    <img src="https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white" alt="Sponsor">
  </a>
</p>

---

<table align="center">
  <tr>
    <td align="center"><img src="Resources/screenshots/onboarding.PNG" width="230" alt="Onboarding"></td>
    <td align="center"><img src="Resources/screenshots/dashboard.PNG" width="230" alt="Dashboard"></td>
  </tr>
  <tr>
    <td align="center"><img src="Resources/screenshots/controls.PNG" width="230" alt="Controls"></td>
    <td align="center"><img src="Resources/screenshots/widgets.png" width="230" alt="Widgets"></td>
  </tr>
</table>

---

## Features

- **Live Dashboard** — real-time print progress, temperatures, fan speeds, layer info, and ETA
- **Camera Streaming** — live camera feed with fullscreen and zoom support
- **AMS Monitoring** — filament status, colors, material types, and drying control
- **Printer Controls** — pause, resume, stop, speed profiles, light toggle, temperature adjustment, fan control, and airduct mode
- **Home Screen Widgets** — camera snapshot, print progress, and AMS status at a glance
- **Fully Local** — your data never leaves your network
- **Localized** — available in English and German

## Requirements

- **iPhone** with iOS 18+
- **Bambu Lab printer** on the same local network

---

## Limitations

### No push notifications or Live Activities

iOS push notifications and Live Activities both require Apple Push Notification service (APNs) — a server-to-Apple-to-device pipeline where a backend sends updates through Apple's servers to your phone. The server authenticates using a `.p8` key tied to the developer's Apple Developer account. This key is a secret that cannot be shared or published.

iOS also does not allow apps to maintain persistent background connections (like MQTT), so the app can't just keep listening on its own.

For a LAN-connected printer, there's no good way to add a server:

- A **centralized server** would need access to each user's local network and printer credentials — breaking the local-only model.
- A **self-hosted server** solves LAN access but can't send APNs notifications without the developer's `.p8` key.

The app works great while it's open — real-time updates, live camera, full control — but background notifications aren't feasible without server infrastructure that conflicts with the local-only, open-source model.

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

