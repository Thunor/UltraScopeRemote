import SwiftUI

// MARK: - Rounded Ring Sector Shape

/// A sector of a hollow ring: rounded corners and evenly-inset edges (the gap width stays constant regardless of radius).
struct RoundedRingSector: Shape {
    var centerAngle: Angle
    var halfSpan: Angle        // Half-angle before insetting (e.g. 45°)
    var innerRatio: CGFloat    // Inner radius / outer radius
    var inset: CGFloat         // Inset per edge (= half the gap width)
    var corner: CGFloat        // Corner radius

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
        // Constant-width gap: the "straight edge" of the gap is actually clipped by the corners between (ro − cr) and (ri + cr),
        // so at these two endpoint radii the perpendicular distance to the gap's centerline must both equal inset:
        //   perpendicular distance = r · sin(45° − φ) = inset  →  φ = 45° − asin(inset / r)
        // Equal distance at both ends ⇒ straight edge parallel to the centerline ⇒ the whole gap has constant width.
        let rEdgeO = ro - cr
        let rEdgeI = ri + cr
        let phiO = half - asin(min(inset / rEdgeO, 1))
        let phiI = half - asin(min(inset / rEdgeI, 1))
        let leadO = t0 - phiO, trailO = t0 + phiO
        let leadI = t0 - phiI, trailI = t0 + phiI
        let dAngO = cr / ro     // Angle on the outer arc corresponding to the corner
        let dAngI = cr / ri     // Angle on the inner arc corresponding to the corner

        let aRad = pt(ro - cr, leadO)        // Outer-leading corner, pulled in radially
        let aArc = pt(ro, leadO + dAngO)     // Outer-leading corner, pulled in along the outer arc
        let bRad = pt(ro - cr, trailO)       // Outer-trailing
        let cRad = pt(ri + cr, trailI)       // Inner-trailing, radial
        let cArc = pt(ri, trailI - dAngI)
        let dRad = pt(ri + cr, leadI)        // Inner-leading

        var p = Path()
        p.move(to: aRad)
        p.addQuadCurve(to: aArc, control: pt(ro, leadO))                                   // Corner: outer-leading
        p.addArc(center: o, radius: ro, startAngle: .radians(Double(leadO + dAngO)),
                 endAngle: .radians(Double(trailO - dAngO)), clockwise: false)              // Outer arc
        p.addQuadCurve(to: bRad, control: pt(ro, trailO))                                   // Corner: outer-trailing
        p.addLine(to: cRad)                                                                 // Trailing radial edge
        p.addQuadCurve(to: cArc, control: pt(ri, trailI))                                   // Corner: inner-trailing
        p.addArc(center: o, radius: ri, startAngle: .radians(Double(trailI - dAngI)),
                 endAngle: .radians(Double(leadI + dAngI)), clockwise: true)                // Inner arc
        p.addQuadCurve(to: dRad, control: pt(ri, leadI))                                    // Corner: inner-leading
        p.closeSubpath()                                                                    // Leading radial edge
        return p
    }
}
