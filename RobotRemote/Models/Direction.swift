import SwiftUI

// MARK: - Direction Definition

enum Direction: CaseIterable {
    case up, down, left, right

    var command: String {
        switch self {
        case .up: "F"; case .down: "B"; case .left: "L"; case .right: "R"
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
