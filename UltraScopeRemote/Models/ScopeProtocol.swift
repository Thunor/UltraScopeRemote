import Foundation

// MARK: - G-code commands (remote → controller)

/// The G-code dialect understood by the UltraScopeController sketch.
/// One command per BLE write, each ≤ 20 bytes so it fits the default BLE MTU.
enum GCode {
    /// Stop all motors and return to manual mode.
    static let stop = "M0"
    static let trackOn = "M100"
    static let trackOff = "M101"
    /// Ask the controller to report its direction and position now.
    static let report = "M114"

    /// Nudge one axis by `steps` motor steps.
    static func jog(_ d: Direction, steps: Int = 1) -> String {
        "G1\(d.axis)\(d.sign * steps)"
    }

    /// Fast move in a direction until `stop` or a limit switch.
    static func fastMove(_ d: Direction) -> String {
        "G0\(d.axis)\(d.sign)"
    }

    /// Slew to equatorial coordinates of date, e.g. "G0A05.9195D+07.4071".
    static func goto(_ eq: Equatorial) -> String {
        "G0" + coordinates(eq)
    }

    /// Tell the controller it is pointing at these coordinates now.
    static func sync(_ eq: Equatorial) -> String {
        "G92" + coordinates(eq)
    }

    private static func coordinates(_ eq: Equatorial) -> String {
        String(format: "A%07.4fD%+08.4f", eq.ra, eq.dec)
    }
}

// MARK: - Status (controller → remote)

/// The latest state the controller has reported over the status characteristic.
struct ScopeStatus: Equatable {
    enum Mode: String {
        case manual = "MAN", track = "TRK", fast = "FST", goto = "GTO", unknown

        var label: String {
            switch self {
            case .manual: "Manual"
            case .track: "Tracking"
            case .fast: "Fast move"
            case .goto: "Slewing"
            case .unknown: "—"
            }
        }
    }

    /// Direction of motion: "N", "S", "E", "W", "NE", "NW", "SE", "SW", or "-" when still.
    var direction = "-"
    var mode = Mode.unknown
    /// Where the scope is pointing; nil until it has been synced.
    var position: Equatorial?
    /// Last error code from the controller ("BAD", "NOSYNC", "LIMIT").
    var error: String?
    /// Bumped on every error so repeated identical errors are still noticed.
    var errorCount = 0

    var isMoving: Bool { direction != "-" }

    var directionLabel: String {
        let names: [Character: String] = ["N": "North", "S": "South", "E": "East", "W": "West"]
        return isMoving ? direction.compactMap { names[$0] }.joined(separator: "-") : "Still"
    }

    var errorMessage: String {
        switch error ?? "" {
        case "NOSYNC": "Sync on a star before GOTO"
        case "LIMIT": "Limit switch hit"
        case "BAD": "Command not understood"
        default: "Error \(error ?? "?")"
        }
    }

    /// Applies one status line, e.g. "D:W M:TRK", "P:05.9195,+07.4071", "P:?" or "E:LIMIT".
    mutating func apply(_ line: String) {
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("D:") {
            for field in line.split(separator: " ") {
                if field.hasPrefix("D:") { direction = String(field.dropFirst(2)) }
                if field.hasPrefix("M:") { mode = Mode(rawValue: String(field.dropFirst(2))) ?? .unknown }
            }
        } else if line.hasPrefix("P:") {
            let parts = line.dropFirst(2).split(separator: ",")
            if parts.count == 2, let ra = Double(parts[0]), let dec = Double(parts[1]) {
                position = Equatorial(ra: ra, dec: dec)
            } else {
                position = nil
            }
        } else if line.hasPrefix("E:") {
            error = String(line.dropFirst(2))
            errorCount += 1
        }
    }
}

extension Equatorial {
    /// e.g. "RA 05h55m10s  Dec +07°24′"
    var formatted: String {
        let totalSeconds = Int((ra * 3600).rounded()) % 86_400
        let arcMinutes = Int((abs(dec) * 60).rounded())
        return String(format: "RA %02dh%02dm%02ds  Dec %@%02d°%02d′",
                      totalSeconds / 3600, totalSeconds / 60 % 60, totalSeconds % 60,
                      dec < 0 ? "−" : "+", arcMinutes / 60, arcMinutes % 60)
    }
}
