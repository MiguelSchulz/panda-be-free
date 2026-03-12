# BambuBeFree

A free, open-source 3D printer dashboard for iOS. Connects directly to your Bambu Lab printer via MQTT on your local network — no cloud, no server, no subscription.

<p align="center">
  <a href="https://testflight.apple.com/join/Tb7w9szg">
    <img src="https://img.shields.io/badge/TestFlight-Join%20Beta-blue?style=for-the-badge&logo=apple" alt="Join TestFlight Beta">
  </a>
</p>

> **Try it now** — join the [TestFlight beta](https://testflight.apple.com/join/Tb7w9szg) to get the latest builds directly on your iPhone.

---

## Features

- **Live Dashboard** — real-time print progress, temperatures, fan speeds, layer info, and ETA
- **Camera Streaming** — live camera feed from your printer with fullscreen and zoom support
- **AMS Monitoring** — filament status, colors, material types, and drying control
- **Printer Controls** — pause, resume, stop, speed profiles, light toggle, temperature adjustment, fan control, and airduct mode
- **Home Screen Widgets** — camera snapshot, print progress, and AMS status at a glance
- **Fully Local** — communicates directly with your printer over LAN. Your data never leaves your network.

## Requirements

- **iPhone** with iOS 18+
- **Bambu Lab printer** on the same local network

---

## Limitations

### Why there are no push notifications or Live Activities

This is a fully local app — your iPhone talks directly to your printer over your home network. That design is great for privacy and simplicity, but it means some iOS features aren't possible.

**Push notifications** on iOS require Apple Push Notification service (APNs). APNs is a server-to-Apple-to-device pipeline: a backend server sends a notification request to Apple's servers, which then deliver it to your phone. To authenticate with APNs, the server needs a `.p8` Authentication Key tied to the developer's Apple Developer account. This key is a secret — anyone who has it can send push notifications to every user of the app. It cannot be shared publicly or committed to an open-source repository.

**Live Activities** (Lock Screen and Dynamic Island) have the same constraint. While they can be *started* locally, keeping them updated when the app is in the background requires ActivityKit push notifications — a special APNs push type (`liveactivity`) that still flows through the same server + `.p8` key infrastructure. Without push-driven updates, Live Activities go stale the moment you leave the app.

iOS also does not allow apps to maintain persistent background connections. There is no background mode that permits keeping an MQTT connection alive indefinitely. Background App Refresh is throttled by the system (intervals of 15+ minutes, adjusted based on usage patterns), which is far too slow for real-time printer monitoring.

**So why not just run a server?** For a LAN-connected printer, there are only two options — and neither works:

| Approach | Problem |
|---|---|
| **Centralized server** | Would need to reach each user's printer, which is on their local network. Users would have to expose their printer to the internet and share their printer credentials with the server — defeating the purpose of local-only communication. |
| **Self-hosted server per user** | Solves the LAN access problem, but the server still can't send APNs notifications without the developer's `.p8` key. Distributing that key would be a security risk and violates Apple's terms. |

This is a fundamental constraint of Apple's push notification architecture, not something that can be worked around with clever engineering. The app works great while it's open — real-time updates, live camera, full control — but background notifications aren't feasible without a server infrastructure that conflicts with the open-source, local-only model.

---

## Upcoming

- **Multi-printer support** — monitor and control multiple printers from a single dashboard
- **Broader printer testing** — currently developed and tested on a **P1S** only. Other Bambu Lab models (X1C, P1P, A1, A1 Mini) should work but haven't been verified yet — reports and feedback from owners of other models are very welcome
- **Android app** — if there's enough interest from the community

---

## Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/miguelschulz/BambuBeFree.git
   cd BambuBeFree
   ```

2. Open the Xcode project:
   ```bash
   open BambuBeFree.xcodeproj
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
