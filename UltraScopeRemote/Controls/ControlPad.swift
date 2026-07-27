import SwiftUI
import Combine

// MARK: - Disc Controller

struct ControlPad: View {
    let discSize: CGFloat
    let send: (String) -> Void

    @State private var active: Direction?
    @State private var stopPressed = false
    @State private var isPressing = false
    @State private var count = 0
    @State private var timer: AnyCancellable?

    @AppStorage("cmd.up") private var cmdNorth = "3"
    @AppStorage("cmd.down") private var cmdSouth = "4"
    @AppStorage("cmd.left") private var cmdWest = "1"
    @AppStorage("cmd.right") private var cmdEast = "2"
    @AppStorage("cmd.stop") private var cmdStop = "0"

    private let innerRatio: CGFloat = 0.46

    private func command(for d: Direction) -> String {
        switch d {
            case .up: String(cmdNorth);
            case .down: String(cmdSouth);
            case .left: String(cmdWest);
            case .right: String(cmdEast)
        }
    }

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
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if active != d {
                                            active = d
                                            send(command(for: d))
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                    }
                                    .onEnded { _ in
                                        active = nil
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
                            )
                            .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                                self.isPressing = pressing
                                if pressing {
                                    self.startTimer(d: d)
                                    print("boom")
                                } else {
                                    self.stopTimer()
                                }
                            }, perform: {
                                send(command(for: d))
                            })
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
                                        send(String(cmdStop))
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
                send(command(for: d))
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
