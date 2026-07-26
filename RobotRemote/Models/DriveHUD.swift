import Foundation

// MARK: - Control Mode

enum ControlMode: String { case joystick, disc }

// MARK: - Command Overlay State

/// Display state for the Dynamic Island-style HUD: the command currently being sent.
struct DriveHUD: Equatable {
    var icon: String = "stop.fill"
    var label: String = "Standby"
    var sending: Bool = false
    var angle: Double = 0      // Arrow rotation angle (degrees), used by the joystick
    var rotates: Bool = false
}
