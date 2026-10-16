import SwiftUI
import Combine

// MARK: - Disc Controller

struct ControlPad: View {
    let discSize: CGFloat
    /// Sends a G-code: tap = jog one step, long press = fast move, center = stop.
    let send: (String) -> Void

    @State private var active: Direction?
    @State private var stopPressed = false
    @State private var isPressing = false
    @State private var count = 0
    @State private var timer: AnyCancellable?

    private let innerRatio: CGFloat = 0.46

    var body: some View {
        let c = discSize / 2
        let iconR = discSize / 2 * (innerRatio + 1) / 2
        let stopSize = discSize * 0.30

        ZStack {
            // Glass layer (including the tint applied while pressed)
            GlassEffectContainer(spacing: 8) {
                ZStack {
                    ForEach(Array(Direction.allCases.enumerated()), id: \.offset) { _, d in
                        let shape = RoundedRingSector(centerAngle: d.centerAngle,
                                                      halfSpan: .degrees(45),
                                                      innerRatio: innerRatio,
                                                      inset: 5, corner: 15)
                        Color.clear
                            .glassEffect(.regular.interactive(), in: shape)
                            .overlay { shape.fill(Color.accentColor).opacity(active == d ? 0.5 : 0) }
                            .frame(width: discSize, height: discSize)
                            .contentShape(shape)
                            .scaleEffect(active == d ? 0.97 : 1)
                            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: active)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded({ _ in
                                        send(GCode.fastMove(d))
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    })
                            )
                            .highPriorityGesture(
                                TapGesture()
                                    .onEnded({ _ in
                                        send(GCode.jog(d))
                                    })
                            )
                    }

                    Color.clear
                        .glassEffect(.regular.interactive(), in: Circle())
                        .overlay { Circle().fill(Color.red).opacity(stopPressed ? 0.6 : 0.14) }
                        .frame(width: stopSize, height: stopSize)
                        .contentShape(Circle())
                        .scaleEffect(stopPressed ? 0.92 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: stopPressed)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !stopPressed {
                                        stopPressed = true
                                        send(GCode.stop)
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                    }
                                }
                                .onEnded { _ in
                                    stopPressed = false
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                        )
                }
                .frame(width: discSize, height: discSize)
            }

            // Icon layer: always above the glass so it isn't blurred; doesn't intercept touches.
            // Use offset to mimic the icon's displacement under "scaleEffect(0.97) from the disc center",
            // rather than applying scaleEffect to the icon itself (that uses a different anchor and makes the icon feel detached from the button).
            ZStack {
                ForEach(Array(Direction.allCases.enumerated()), id: \.offset) { _, d in
                    let angle = CGFloat(d.centerAngle.radians)
                    Image(systemName: d.icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(active == d ? Color.white : Color.primary)
                        .offset(x: active == d ? -cos(angle) * iconR * 0.03 : 0,
                                y: active == d ? -sin(angle) * iconR * 0.03 : 0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: active)
                        .position(x: c + cos(angle) * iconR,
                                  y: c + sin(angle) * iconR)
                }
                // The stop key sits at the exact disc center, so scaleEffect anchors on the center and needs no offset correction.
                Image(systemName: "stop.fill")
                    .font(.system(size: stopSize * 0.4, weight: .bold))
                    .foregroundStyle(stopPressed ? Color.white : Color.red)
                    .scaleEffect(stopPressed ? 0.92 : 1)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: stopPressed)
                    .position(x: c, y: c)
            }
            .allowsHitTesting(false)
        }
        .frame(width: discSize, height: discSize)
    }
    
    private func startTimer(d: Direction) {
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.count += 1
                print("repeat: \(d)")
                send(GCode.jog(d))
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
