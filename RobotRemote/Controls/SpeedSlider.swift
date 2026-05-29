import SwiftUI

// MARK: - 仿生速度拉桿

/// 自訂滑動控制：旋鈕跟隨手指、填充隨值延伸，跨越整數刻度時觸發輕微觸覺段落感。
/// 數值直接顯示在旋鈕上。支援水平（直向）與垂直（橫向）兩種方向。
struct SpeedSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 5...50
    var axis: Axis = .horizontal
    var length: CGFloat = 300

    private let thickness: CGFloat = 60
    private var knob: CGFloat { thickness - 12 }

    @State private var dragging = false

    private var fraction: CGFloat {
        let f = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(max(0, min(1, f)))
    }

    private var stackAlignment: Alignment { axis == .horizontal ? .leading : .bottom }

    var body: some View {
        GeometryReader { geo in
            let len = axis == .horizontal ? geo.size.width : geo.size.height
            let inset = (thickness - knob) / 2          // 旋鈕置中於端點半圓所需的內縮
            let travel = max(1, len - thickness)
            let pos = inset + fraction * travel          // 旋鈕前緣偏移
            let fillLen = min(len, pos + knob / 2 + thickness / 2)  // 填到旋鈕圓心並補滿端點半圓

            ZStack(alignment: stackAlignment) {
                ZStack(alignment: stackAlignment) {
                    Capsule()
                        .glassEffect(.regular, in: Capsule())
                        .overlay { Capsule().strokeBorder(.secondary.opacity(0.25), lineWidth: 1) }

                    fillView(fillLen)
                    endpointIcons
                }
                .clipShape(Capsule())

                knobView
                    .offset(axis == .horizontal ? CGSize(width: pos, height: 0)
                                                : CGSize(width: 0, height: -pos))
                    .animation(dragging ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: value)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: dragging)
            }
            .contentShape(Capsule())
            .gesture(drag(len: len, travel: travel))
        }
        .frame(width: axis == .horizontal ? length : thickness,
               height: axis == .horizontal ? thickness : length)
    }

    @ViewBuilder
    private func fillView(_ fillLen: CGFloat) -> some View {
        let bar = Capsule().fill(Color.accentColor.gradient.opacity(0.9))
        if axis == .horizontal {
            bar.frame(width: fillLen)
        } else {
            bar.frame(height: fillLen)
        }
    }

    private var endpointIcons: some View {
        let pad = thickness * 0.28
        return Group {
            if axis == .horizontal {
                HStack {
                    Image(systemName: "tortoise.fill")
                    Spacer()
                    Image(systemName: "hare.fill")
                }
                .padding(.horizontal, pad)
            } else {
                VStack {
                    Image(systemName: "hare.fill")
                    Spacer()
                    Image(systemName: "tortoise.fill")
                }
                .padding(.vertical, pad)
            }
        }
        .font(.system(size: thickness * 0.26))
        .foregroundStyle(.secondary.opacity(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var knobView: some View {
        Circle()
            .fill(Color.accentColor.gradient)
            .overlay { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2) }
            .overlay {
                Text("\(Int(value.rounded()))")
                    .font(.system(size: knob * 0.34, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .shadow(color: .black.opacity(0.25), radius: dragging ? 10 : 6, y: 3)
            .frame(width: knob, height: knob)
            .scaleEffect(dragging ? 1.08 : 1)
    }

    private func drag(len: CGFloat, travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                if !dragging {
                    dragging = true
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                let raw: CGFloat = axis == .horizontal ? g.location.x : (len - g.location.y)
                let frac = max(0, min(1, (raw - thickness / 2) / travel))
                let span = range.upperBound - range.lowerBound
                let newVal = (range.lowerBound + Double(frac) * span).rounded()
                if Int(newVal) != Int(value) {
                    value = newVal
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .onEnded { _ in
                dragging = false
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
    }
}
