# RobotRemote

以 SwiftUI 打造的 iOS App，透過藍牙低功耗（BLE）遙控 Arduino 自走車。支援類比搖桿與圓盤方向鍵兩種操控模式，並可自訂送出的指令字元。

## 功能

- **搖桿模式** — 類比搖桿，以差速混控即時換算左右輪轉速，拖曳期間固定回報向量。
- **方向鍵模式** — Liquid Glass 風格圓盤，前後左右 + 中央停止鍵。
- **指令浮層 HUD** — 動態島風格，即時顯示正在送出的指令。
- **自訂指令** — 可改寫每個方向與停止鍵送出的 ASCII 字元，對應 Arduino 端的辨識邏輯。
- **預覽模式** — 不需連接硬體即可在實機上測試介面。

## 硬體需求

- iOS 裝置（需支援 BLE）
- Arduino（本專案以 **Arduino Uno R4** 開發）
- **HC-08** BLE 藍牙模組（與 HM-10 相容）
  - Service UUID：`FFE0`
  - Characteristic UUID：`FFE1`

## 通訊協定

App 透過 BLE 透明序列傳送 ASCII 字串給 Arduino：

| 模式 | 格式 | 範例 | 說明 |
| --- | --- | --- | --- |
| 方向鍵 | 單一字元 | `F` `B` `L` `R` `S` | 前進 / 後退 / 左轉 / 右轉 / 停止（字元可自訂） |
| 方向鍵 | `V<rpm>\n` | `V50\n` | 設定方向鍵模式的執行轉速 |
| 搖桿 | `M<L>,<R>\n` | `M50,-20\n` | 左輪、右輪目標 RPM |

## 開發環境

- Xcode 16+
- iOS 26+（使用了 Liquid Glass 等新 API）

## 建置與執行

```bash
git clone https://github.com/robotctust/robot-bluetooth-remote-app-for-ios.git
cd robot-bluetooth-remote-app-for-ios
open RobotRemote.xcodeproj
```

在 Xcode 中選擇實體 iOS 裝置後按 ⌘R 執行。
（藍牙在模擬器上無法運作，請用實機；或在 App 設定中開啟「預覽模式」測試介面。）

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

## 授權

本專案以 [MIT License](LICENSE) 授權釋出，歡迎貢獻。
