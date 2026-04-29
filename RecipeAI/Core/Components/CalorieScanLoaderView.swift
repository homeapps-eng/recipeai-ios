import SwiftUI

/// Loading animation shown over the captured photo while calorie estimation
/// is in flight. SwiftUI port of the Android `CalorieScanView`.
///
/// 4.5-second seamless cycle:
/// - 0.00–0.10  dark overlay fades in
/// - 0.00–0.55  scan line sweeps top-to-bottom with a gradient trail
/// - 0.20–0.50  six detected ingredient nodes pop in one by one
/// - 0.30–0.70  neural-network edges draw between adjacent nodes
/// - 0.95–1.00  fade for clean loop boundary
struct CalorieScanLoaderView: View {

    private let cycleSec: Double = 4.5
    private let brandGreen = Color(hex: "00A86B")

    private struct Edge {
        let a: Int
        let b: Int
        let appearAt: Double
    }

    private let edges: [Edge] = [
        .init(a: 0, b: 1, appearAt: 0.30),
        .init(a: 0, b: 2, appearAt: 0.36),
        .init(a: 1, b: 2, appearAt: 0.42),
        .init(a: 2, b: 3, appearAt: 0.48),
        .init(a: 2, b: 4, appearAt: 0.54),
        .init(a: 3, b: 5, appearAt: 0.60),
        .init(a: 4, b: 5, appearAt: 0.66)
    ]

    private let nodeAppearAt: [Double] = [0.20, 0.26, 0.32, 0.38, 0.44, 0.50]

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let t = (elapsed.truncatingRemainder(dividingBy: cycleSec)) / cycleSec

                let globalAlpha: Double = {
                    if t < 0.05 { return t / 0.05 }
                    if t > 0.95 { return 1.0 - (t - 0.95) / 0.05 }
                    return 1.0
                }()

                let nodes = nodePositions(in: size)

                drawDarkOverlay(ctx: &ctx, size: size, t: t, globalAlpha: globalAlpha)
                drawScanLine(ctx: &ctx, size: size, t: t, globalAlpha: globalAlpha)
                drawEdges(ctx: &ctx, t: t, globalAlpha: globalAlpha, nodes: nodes)
                drawNodes(ctx: &ctx, t: t, globalAlpha: globalAlpha, nodes: nodes)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drawing

    private func nodePositions(in size: CGSize) -> [CGPoint] {
        let w = size.width
        let h = size.height
        return [
            CGPoint(x: w * 0.30, y: h * 0.32),
            CGPoint(x: w * 0.66, y: h * 0.26),
            CGPoint(x: w * 0.50, y: h * 0.50),
            CGPoint(x: w * 0.32, y: h * 0.66),
            CGPoint(x: w * 0.72, y: h * 0.62),
            CGPoint(x: w * 0.48, y: h * 0.80)
        ]
    }

    private func drawDarkOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double, globalAlpha: Double) {
        let alpha = min(t / 0.10, 1.0) * 0.28 * globalAlpha
        guard alpha > 0 else { return }
        let rect = CGRect(origin: .zero, size: size)
        ctx.fill(Path(rect), with: .color(.black.opacity(alpha)))
    }

    private func drawScanLine(ctx: inout GraphicsContext, size: CGSize, t: Double, globalAlpha: Double) {
        guard t <= 0.6 else { return }
        let sweep = min(t / 0.55, 1.0)
        let y = size.height * sweep
        let trailHeight: Double = 80

        let trailTop = max(0, y - trailHeight)
        let trailAlphaBase = max(0, min(1, globalAlpha * 0.55 * (1.0 - (t / 0.6))))

        // Trailing glow gradient
        let trailRect = CGRect(x: 0, y: trailTop, width: size.width, height: y - trailTop)
        let gradient = Gradient(stops: [
            .init(color: brandGreen.opacity(0), location: 0),
            .init(color: brandGreen.opacity(trailAlphaBase), location: 1)
        ])
        ctx.fill(
            Path(trailRect),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: 0, y: trailTop),
                endPoint: CGPoint(x: 0, y: y)
            )
        )

        // Sharp scan line
        let lineRect = CGRect(x: 0, y: y - 1, width: size.width, height: 2)
        ctx.fill(Path(lineRect), with: .color(brandGreen.opacity(globalAlpha * 0.9)))
    }

    private func drawEdges(ctx: inout GraphicsContext, t: Double, globalAlpha: Double, nodes: [CGPoint]) {
        for edge in edges {
            guard edge.a < nodes.count, edge.b < nodes.count else { continue }
            let phase = max(0, min(1, (t - edge.appearAt) / 0.18))
            guard phase > 0 else { continue }

            let nodeA = nodes[edge.a]
            let nodeB = nodes[edge.b]
            let cx = nodeA.x + (nodeB.x - nodeA.x) * phase
            let cy = nodeA.y + (nodeB.y - nodeA.y) * phase

            let pulse = 0.55 + 0.20 * sin((t * .pi * 4) + Double(edge.a + edge.b))
            let alpha = phase * pulse * globalAlpha

            var path = Path()
            path.move(to: nodeA)
            path.addLine(to: CGPoint(x: cx, y: cy))
            ctx.stroke(
                path,
                with: .color(brandGreen.opacity(alpha * 0.78)),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
            )
        }
    }

    private func drawNodes(ctx: inout GraphicsContext, t: Double, globalAlpha: Double, nodes: [CGPoint]) {
        let baseRadius: Double = 4.2
        for (i, pos) in nodes.enumerated() {
            guard i < nodeAppearAt.count else { continue }
            let phase = (t - nodeAppearAt[i]) / 0.12
            guard phase > 0 else { continue }
            let visible = max(0, min(1, phase))

            let scale: Double
            if phase < 1 {
                let u = phase
                scale = u < 0.5 ? u * 2.6 : 1.3 - (u - 0.5) * 0.6
            } else {
                scale = 1.0
            }

            let alpha = visible * globalAlpha
            let r = baseRadius * scale

            // Outer expanding ring (ping)
            let ringPhase = min(phase * 0.6, 1)
            let ringRadius = r * (1.5 + ringPhase * 1.5)
            let ringAlpha = (1 - ringPhase) * alpha * 0.55
            let ringPath = Path(ellipseIn: CGRect(
                x: pos.x - ringRadius,
                y: pos.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            ))
            ctx.stroke(ringPath, with: .color(brandGreen.opacity(ringAlpha)), lineWidth: 1.4)

            // Filled core
            let coreRect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: coreRect), with: .color(brandGreen.opacity(alpha * 0.95)))

            // Inner highlight
            let hr = r * 0.4
            let hRect = CGRect(x: pos.x - hr, y: pos.y - hr, width: hr * 2, height: hr * 2)
            ctx.fill(Path(ellipseIn: hRect), with: .color(.white.opacity(alpha * 0.85)))
        }
    }
}

#Preview {
    ZStack {
        Image(systemName: "photo")
            .font(.system(size: 200))
            .foregroundColor(.gray.opacity(0.3))
            .frame(width: 320, height: 320)
            .background(Color.gray.opacity(0.15))
        CalorieScanLoaderView()
    }
    .frame(width: 320, height: 320)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
