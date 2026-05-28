import SwiftUI

// MARK: - 圓潤弧形扇段 Shape

/// 中空圓環的一段扇形：四角圓潤、四邊等寬內縮（縫隙寬度不隨半徑變窄）。
struct RoundedRingSector: Shape {
    var centerAngle: Angle
    var halfSpan: Angle        // 未內縮前的半張角（例如 45°）
    var innerRatio: CGFloat    // 內半徑 / 外半徑
    var inset: CGFloat         // 每邊內縮量（= 縫隙寬度的一半）
    var corner: CGFloat        // 圓角半徑

    func path(in rect: CGRect) -> Path {
        let o = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) / 2
        let innerR = outerR * innerRatio
        let ro = outerR - inset
        let ri = innerR + inset
        let cr = max(2, min(corner, (ro - ri) / 2 - 1))

        func pt(_ r: CGFloat, _ a: CGFloat) -> CGPoint {
            CGPoint(x: o.x + r * cos(a), y: o.y + r * sin(a))
        }

        let t0 = CGFloat(centerAngle.radians)
        let half = CGFloat(halfSpan.radians)
        // 等寬縫隙：縫隙的「直邊」其實被圓角截斷在 (ro − cr) 與 (ri + cr) 之間，
        // 故要在這兩個端點半徑上、讓到縫隙中線的垂直距離都等於 inset：
        //   垂直距離 = r · sin(45° − φ) = inset  →  φ = 45° − asin(inset / r)
        // 兩端等距 ⇒ 直邊平行於中線 ⇒ 整條縫隙等寬。
        let rEdgeO = ro - cr
        let rEdgeI = ri + cr
        let phiO = half - asin(min(inset / rEdgeO, 1))
        let phiI = half - asin(min(inset / rEdgeI, 1))
        let leadO = t0 - phiO, trailO = t0 + phiO
        let leadI = t0 - phiI, trailI = t0 + phiI
        let dAngO = cr / ro     // 外弧上對應圓角的角度
        let dAngI = cr / ri     // 內弧上對應圓角的角度

        let aRad = pt(ro - cr, leadO)        // 外-前 角，沿徑向收進
        let aArc = pt(ro, leadO + dAngO)     // 外-前 角，沿外弧收進
        let bRad = pt(ro - cr, trailO)       // 外-後
        let cRad = pt(ri + cr, trailI)       // 內-後，沿徑向
        let cArc = pt(ri, trailI - dAngI)
        let dRad = pt(ri + cr, leadI)        // 內-前

        var p = Path()
        p.move(to: aRad)
        p.addQuadCurve(to: aArc, control: pt(ro, leadO))                                   // 圓角：外-前
        p.addArc(center: o, radius: ro, startAngle: .radians(Double(leadO + dAngO)),
                 endAngle: .radians(Double(trailO - dAngO)), clockwise: false)              // 外弧
        p.addQuadCurve(to: bRad, control: pt(ro, trailO))                                   // 圓角：外-後
        p.addLine(to: cRad)                                                                 // 後側徑向邊
        p.addQuadCurve(to: cArc, control: pt(ri, trailI))                                   // 圓角：內-後
        p.addArc(center: o, radius: ri, startAngle: .radians(Double(trailI - dAngI)),
                 endAngle: .radians(Double(leadI + dAngI)), clockwise: true)                // 內弧
        p.addQuadCurve(to: dRad, control: pt(ri, leadI))                                    // 圓角：內-前
        p.closeSubpath()                                                                    // 前側徑向邊
        return p
    }
}
