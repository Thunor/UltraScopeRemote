import Foundation

// MARK: - 控制模式

enum ControlMode: String { case joystick, disc }

// MARK: - 指令浮層狀態

/// 動態島風格 HUD 的顯示狀態：目前送出的指令。
struct DriveHUD: Equatable {
    var icon: String = "stop.fill"
    var label: String = "待命"
    var sending: Bool = false
    var angle: Double = 0      // 箭頭旋轉角（度），搖桿用
    var rotates: Bool = false
}
