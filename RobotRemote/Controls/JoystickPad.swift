import SwiftUI

// MARK: - Joystick Controller

/// Analog joystick: the thumb knob follows the finger, is clamped within the base, and auto-recenters on release.
/// While dragging, it reports a normalized vector at a fixed 20 Hz (math coordinates: up is +y, right is +x, length 0–1).
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
            // Base (glass layer)
            GlassEffectContainer(spacing: 8) {
                Color.clear
                    .glassEffect(.regular, in: Circle())
                    .overlay { Circle().strokeBorder(.secondary.opacity(0.25), lineWidth: 1) }
                    .frame(width: size, height: size)
            }

            // Center crosshair hint
            Image(systemName: "plus")
                .font(.system(size: size * 0.10, weight: .light))
                .foregroundStyle(.secondary.opacity(0.4))

            // Thumb knob: a solid knob layered above the glass so it isn't blurred
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
