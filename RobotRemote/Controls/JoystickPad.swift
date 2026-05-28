import SwiftUI

// MARK: - 搖桿控制器

/// 類比搖桿：拇指鈕跟隨手指、夾限在底盤內，放開自動回中。
/// 拖曳期間以固定 20Hz 回報正規化向量（數學座標：上為 +y、右為 +x，長度 0–1）。
struct JoystickPad: View {
    let size: CGFloat
    let onVector: (CGVector) -> Void
    let onRelease: () -> Void

    @State private var thumb: CGSize = .zero
    @State private var dragging = false

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var thumbDiameter: CGFloat { size * 0.38 }
    private var travel: CGFloat { size / 2 - thumbDiameter / 2 }

    private var vector: CGVector {
        guard travel > 0 else { return .zero }
        return CGVector(dx: thumb.width / travel, dy: -thumb.height / travel)
    }

    var body: some View {
        ZStack {
            // 底盤（玻璃層）
            GlassEffectContainer(spacing: 8) {
                Color.clear
                    .glassEffect(.regular, in: Circle())
                    .overlay { Circle().strokeBorder(.secondary.opacity(0.25), lineWidth: 1) }
                    .frame(width: size, height: size)
            }

            // 中心十字提示
            Image(systemName: "plus")
                .font(.system(size: size * 0.10, weight: .light))
                .foregroundStyle(.secondary.opacity(0.4))

            // 拇指鈕：實心旋鈕，疊在玻璃之上不被模糊
            Circle()
                .fill(Color.accentColor.gradient)
                .overlay { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2) }
                .overlay {
                    Image(systemName: "dot.scope")
                        .font(.system(size: thumbDiameter * 0.34, weight: .bold))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.25), radius: dragging ? 10 : 6, y: 3)
                .frame(width: thumbDiameter, height: thumbDiameter)
                .scaleEffect(dragging ? 1.06 : 1)
                .offset(thumb)
                .animation(dragging ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: thumb)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: dragging)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if !dragging {
                        dragging = true
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    var t = g.translation
                    let dist = sqrt(t.width * t.width + t.height * t.height)
                    if dist > travel, dist > 0 {
                        let k = travel / dist
                        t = CGSize(width: t.width * k, height: t.height * k)
                    }
                    thumb = t
                }
                .onEnded { _ in
                    dragging = false
                    thumb = .zero
                    onRelease()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
        )
        .onReceive(tick) { _ in
            if dragging { onVector(vector) }
        }
    }
}
