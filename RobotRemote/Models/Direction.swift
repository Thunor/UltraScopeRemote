import SwiftUI

// MARK: - 方向定義

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

    /// SwiftUI 角度：0° 在右側，順時針為正。
    var centerAngle: Angle {
        switch self {
        case .up: .degrees(-90); case .right: .degrees(0)
        case .down: .degrees(90); case .left: .degrees(180)
        }
    }
}
