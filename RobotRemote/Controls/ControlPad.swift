import SwiftUI

// MARK: - 圓盤控制器

struct ControlPad: View {
    let discSize: CGFloat
    let send: (String) -> Void

    @State private var active: Direction?
    @State private var stopPressed = false

    @AppStorage("cmd.up") private var cmdUp = "F"
    @AppStorage("cmd.down") private var cmdDown = "B"
    @AppStorage("cmd.left") private var cmdLeft = "L"
    @AppStorage("cmd.right") private var cmdRight = "R"
    @AppStorage("cmd.stop") private var cmdStop = "S"

    private let innerRatio: CGFloat = 0.46

    private func command(for d: Direction) -> String {
        switch d {
        case .up: cmdUp; case .down: cmdDown; case .left: cmdLeft; case .right: cmdRight
        }
    }

    var body: some View {
        let c = discSize / 2
        let iconR = discSize / 2 * (innerRatio + 1) / 2
        let stopSize = discSize * 0.30

        ZStack {
            // 玻璃層（含按下時的著色）
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
                                        send(cmdStop)
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    }
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
                                        send(cmdStop)
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

            // 圖示層：永遠在玻璃之上，不被模糊；不攔截觸控。
            // 用 offset 模擬「從圓盤中心 scaleEffect(0.97)」時圖示的位移量，
            // 而非對圖示自身做 scaleEffect（那樣錨點不同，會感覺圖示和按鈕分離）。
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
                // 停止鍵在圓盤正中心，scaleEffect 錨點即圓心，不需要 offset 修正。
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
}
