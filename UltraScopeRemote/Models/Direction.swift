import SwiftUI

// MARK: - Direction Definition

enum Direction: CaseIterable {
    case up, down, left, right

    /// Controller axis: X is RA, Y is Dec.
    var axis: String {
        switch self {
        case .up, .down: "Y"; case .left, .right: "X"
        }
    }

    /// Axis sign: + is west (RA) or north/up (Dec).
    var sign: Int {
        switch self {
        case .up, .left: 1; case .down, .right: -1
        }
    }

    var compassName: String {
        switch self {
        case .up: "North"; case .down: "South"; case .left: "West"; case .right: "East"
        }
    }

    var icon: String {
        switch self {
        case .up: "chevron.up"; case .down: "chevron.down"
        case .left: "chevron.left"; case .right: "chevron.right"
        }
    }

    /// SwiftUI angle: 0° is on the right, clockwise is positive.
    var centerAngle: Angle {
        switch self {
        case .up: .degrees(-90); case .right: .degrees(0)
        case .down: .degrees(90); case .left: .degrees(180)
        }
    }
}
