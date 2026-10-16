<div align="center">

<img src="docs/robotctust-iOS-Dark-512x512@1x.png" alt="Robot Remote" width="180">

# Robot Remote

**Control your Arduino robot car over Bluetooth**

An iOS app built with SwiftUI that remotely controls an Arduino robot car via Bluetooth Low Energy (BLE).<br>
Supports both analog joystick and disc directional-pad control modes, and lets you customize the command characters that are sent.

<p>
  <img src="https://img.shields.io/badge/platform-iOS%2026%2B-000000?logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/built%20with-SwiftUI-FA7343?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Xcode-16%2B-1575F9?logo=xcode&logoColor=white" alt="Xcode">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT"></a>
</p>

</div>

---

## Features

| Feature | Description |
| --- | --- |
| **Joystick mode** | Analog joystick that converts to left/right wheel speeds in real time using differential mixing, reporting the vector at a fixed rate while dragging. |
| **Directional-pad mode** | A Liquid Glass-style disc with forward/back/left/right plus a central stop key. |
| **Command HUD overlay** | Dynamic Island-style overlay that shows the command currently being sent in real time. |
| **Custom commands** | Rewrite the ASCII character sent for each direction and the stop key, matching the recognition logic on the Arduino side. |
| **Preview mode** | Test the interface on a real device without connecting to hardware. |

## Hardware Requirements

- An iOS device
- An Arduino (this project was developed with an **Arduino Uno R4**)
- An **HC-08** BLE Bluetooth module (compatible with the HM-10)

| Item | Value |
| --- | --- |
| Service UUID | `FFE0` |
| Characteristic UUID | `FFE1` |

## Communication Protocol

The app and the UltraScopeController sketch speak a small G-code dialect over BLE service `180A`.
Each command is one write to characteristic `2A57` (≤ 20 bytes; spaces and newline optional).

| Command | Example | Description |
| --- | --- | --- |
| `G0 X±1` / `G0 Y±1` | `G0X-1` | Fast move RA (+ west / − east) or Dec (+ north / − south) until `M0` or a limit switch |
| `G0 A<ra> D<dec>` | `G0A05.9195D+07.4071` | GOTO equatorial coordinates of date (RA hours, Dec degrees). Needs a sync first; tracks on arrival |
| `G1 X<n>` / `G1 Y<n>` | `G1X1` | Jog an axis `n` motor steps |
| `G92 A<ra> D<dec>` | `G92A05.9195D+07.4071` | Sync: the scope is centered on these coordinates |
| `M0` | | Stop, manual mode |
| `M100` / `M101` | | Tracking on / off |
| `M114` | | Report direction and position now |

The controller notifies on characteristic `2A3D` (each message ≤ 20 bytes):

| Message | Example | Description |
| --- | --- | --- |
| `D:<dir> M:<mode>` | `D:W M:TRK` | Direction of motion (`N S E W NE NW SE SW`, `-` when still) and mode (`MAN TRK FST GTO`); sent on change |
| `P:<ra>,<dec>` | `P:05.9195,+07.4071` | Where the scope points, every 2 s once synced (`P:?` before) |
| `E:<code>` | `E:LIMIT` | Error: `BAD`, `NOSYNC` or `LIMIT` |

## Build and Run

**Requirements:** Xcode 16+ · iOS 26+ (uses new APIs such as Liquid Glass)

```bash
git clone https://github.com/robotctust/robot-bluetooth-remote-app-for-ios.git
cd robot-bluetooth-remote-app-for-ios
open RobotRemote.xcodeproj
```

Select a physical iOS device in Xcode, then press <kbd>⌘R</kbd> to run.

> [!NOTE]
> Bluetooth does not work in the simulator, so use a real device; alternatively, enable "Preview Mode" in the app's settings to test the interface.

## Project Structure

```
RobotRemote/
├── RobotRemoteApp.swift        App entry point
├── BluetoothManager.swift      CoreBluetooth connection management
├── ContentView.swift           Root TabView
├── Models/                     Data types (direction, control mode, HUD state)
├── Controls/                   Reusable control components (joystick, disc, Shape)
└── Screens/                    Individual screens (remote, settings, device picker)
```

## Contributing

Feel free to open an Issue to report problems or share ideas, and Pull Requests are welcome too:

1. Fork this project and create a branch (`git checkout -b feature/your-feature`)
2. Commit your changes (`git commit -m 'Add some feature'`)
3. Push the branch (`git push origin feature/your-feature`)
4. Open a Pull Request

## License

This project is released under the [MIT License](LICENSE).

<div align="center">
<sub>Copyright © 2026 Central Taiwan Robotics Club · Made with SwiftUI</sub>
</div>
