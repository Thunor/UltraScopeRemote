<div align="center">

<img src="docs/robotctust-iOS-Dark-512x512@1x.png" alt="Robot Remote" width="180">

# Robot Remote

**用藍牙遙控你的 Arduino 自走車**

以 SwiftUI 打造的 iOS App，透過藍牙低功耗（BLE）遙控 Arduino 自走車。<br>
支援類比搖桿與圓盤方向鍵兩種操控模式，並可自訂送出的指令字元。

<p>
  <img src="https://img.shields.io/badge/platform-iOS%2026%2B-000000?logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/built%20with-SwiftUI-FA7343?logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Xcode-16%2B-1575F9?logo=xcode&logoColor=white" alt="Xcode">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License: MIT"></a>
</p>

</div>

---

## 功能

| 功能 | 說明 |
| --- | --- |
| **搖桿模式** | 類比搖桿，以差速混控即時換算左右輪轉速，拖曳期間固定回報向量。 |
| **方向鍵模式** | Liquid Glass 風格圓盤，前後左右 + 中央停止鍵。 |
| **指令浮層 HUD** | 動態島風格，即時顯示正在送出的指令。 |
| **自訂指令** | 可改寫每個方向與停止鍵送出的 ASCII 字元，對應 Arduino 端的辨識邏輯。 |
| **預覽模式** | 不需連接硬體即可在實機上測試介面。 |

## 硬體需求

- iOS 裝置
- Arduino（本專案以 **Arduino Uno R4** 開發）
- **HC-08** BLE 藍牙模組（與 HM-10 相容）

| 項目 | 值 |
| --- | --- |
| Service UUID | `FFE0` |
| Characteristic UUID | `FFE1` |

## 通訊協定

App 透過 BLE 透明序列傳送 ASCII 字串給 Arduino：

| 模式 | 格式 | 範例 | 說明 |
| --- | --- | --- | --- |
| 方向鍵 | 單一字元 | `F` `B` `L` `R` `S` | 前進 / 後退 / 左轉 / 右轉 / 停止（字元可自訂） |
| 方向鍵 | `V<rpm>\n` | `V50\n` | 設定方向鍵模式的執行轉速 |
| 搖桿 | `M<L>,<R>\n` | `M50,-20\n` | 左輪、右輪目標 RPM |

## 建置與執行

**環境需求：** Xcode 16+ · iOS 26+（使用了 Liquid Glass 等新 API）

```bash
git clone https://github.com/robotctust/robot-bluetooth-remote-app-for-ios.git
cd robot-bluetooth-remote-app-for-ios
open RobotRemote.xcodeproj
```

在 Xcode 中選擇實體 iOS 裝置後按 <kbd>⌘R</kbd> 執行。

> [!NOTE]
> 藍牙在模擬器上無法運作，請用實機；或在 App 設定中開啟「預覽模式」測試介面。

## 專案結構

```
RobotRemote/
├── RobotRemoteApp.swift        App 進入點
├── BluetoothManager.swift      CoreBluetooth 連線管理
├── ContentView.swift           根 TabView
├── Models/                     資料型別（方向、控制模式、HUD 狀態）
├── Controls/                   可重用控制元件（搖桿、圓盤、Shape）
└── Screens/                    各頁面（遙控、設定、裝置選擇）
```

## 貢獻

歡迎發 Issue 回報問題或提出想法，也歡迎送 Pull Request：

1. Fork 本專案並建立分支（`git checkout -b feature/your-feature`）
2. 提交變更（`git commit -m 'Add some feature'`）
3. 推送分支（`git push origin feature/your-feature`）
4. 開啟 Pull Request

## 授權

本專案以 [MIT License](LICENSE) 授權釋出。

<div align="center">
<sub>Copyright © 2026 中臺機器人研究社 · Made with SwiftUI</sub>
</div>
