import SwiftUI

/// Loading animation shown over the recipe image placeholder while the AI
/// image is being generated. SwiftUI port of the Android `CookingSteamView`.
///
/// 5-second seamless cycle:
/// - 0.50–0.85   five ingredient lights pop in one by one
/// - 0.85–0.95   subtle radial pulse around the composition
/// - 0.95–1.00   gentle global fade out for a clean loop boundary
/// Plus continuous "thought" particles drifting along Lissajous paths.
struct CookingSteamLoaderView: View {

    private let cycleSec: Double = 5.0
    private let ingredientCount = 5
    private let brandGreen = Color(hex: "00A86B")

    private struct Thought {
        let freqX: Double
        let freqY: Double
        let ampX: Double
        let ampY: Double
        let shift: Double
    }
    private let thoughts: [Thought] = [
        .init(freqX: 1.7, freqY: 1.1, ampX: 0.32, ampY: 0.22, shift: 0.00),
        .init(freqX: 1.3, freqY: 1.9, ampX: 0.28, ampY: 0.18, shift: 0.27),
        .init(freqX: 2.1, freqY: 0.9, ampX: 0.36, ampY: 0.24, shift: 0.51),
        .init(freqX: 1.0, freqY: 1.5, ampX: 0.30, ampY: 0.20, shift: 0.74),
        .init(freqX: 1.8, freqY: 1.3, ampX: 0.26, ampY: 0.16, shift: 0.13)
    ]

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

                drawThoughtParticles(ctx: &ctx, size: size, t: t)
                drawPulse(ctx: &ctx, size: size, t: t, globalAlpha: globalAlpha)
                drawIngredients(ctx: &ctx, size: size, t: t, globalAlpha: globalAlpha)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Drawing

    private func drawThoughtParticles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseRadius = 1.6
        let baseAlpha = 0.55
        for th in thoughts {
            let phase = (t + th.shift).truncatingRemainder(dividingBy: 1.0)
            let theta = phase * .pi * 2
            let cx = size.width * 0.5 + sin(theta * th.freqX) * size.width * th.ampX
            let cy = size.height * 0.5 + cos(theta * th.freqY) * size.height * th.ampY
            let pulse = 0.6 + 0.4 * sin(theta * 2)
            drawGlow(
                ctx: &ctx,
                cx: cx,
                cy: cy,
                radius: baseRadius,
                alpha: baseAlpha * pulse,
                color: brandGreen
            )
        }
    }

    private func drawPulse(ctx: inout GraphicsContext, size: CGSize, t: Double, globalAlpha: Double) {
        guard t >= 0.85, t <= 0.95 else { return }
        let u = (t - 0.85) / 0.10
        let radius = lerp(60.0, 110.0, u)
        let alpha = (1.0 - u) * 0.6 * globalAlpha
        let center = CGPoint(x: size.width / 2, y: size.height * 0.66)
        let path = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        ctx.stroke(
            path,
            with: .color(brandGreen.opacity(alpha)),
            lineWidth: 1.8
        )
    }

    private func drawIngredients(ctx: inout GraphicsContext, size: CGSize, t: Double, globalAlpha: Double) {
        let cx = size.width / 2
        let cy = size.height * 0.59
        let rx = size.width * 0.16
        let ry = size.height * 0.03
        let angles: [Double] = [-2.4, -1.0, 0.4, 1.6, 2.9]
        let baseRadius = 4.0

        for i in 0..<ingredientCount {
            let appearAt = 0.50 + Double(i) * 0.07
            let life = (t - appearAt) / 0.40
            guard life > 0, life < 1 else { continue }

            let a = angles[i]
            let posX = cx + cos(a) * rx * 0.7
            let posY = cy + sin(a) * ry * 0.9

            let scale: Double
            let alpha: Double
            if life < 0.18 {
                let u = life / 0.18
                scale = u < 0.55 ? u * 2.27 : 1.25 - (u - 0.55) * 0.55
                alpha = u
            } else if life < 0.85 {
                scale = 1.0
                alpha = 1.0
            } else {
                let u = (life - 0.85) / 0.15
                scale = 1.0
                alpha = 1.0 - u
            }

            let radius = baseRadius * scale
            drawGlow(
                ctx: &ctx,
                cx: posX,
                cy: posY,
                radius: radius,
                alpha: alpha * globalAlpha,
                color: brandGreen
            )
        }
    }

    private func drawGlow(
        ctx: inout GraphicsContext,
        cx: Double,
        cy: Double,
        radius: Double,
        alpha: Double,
        color: Color
    ) {
        guard alpha > 0, radius > 0 else { return }
        // Outer halo
        let halo = Path(ellipseIn: CGRect(x: cx - radius * 2.8, y: cy - radius * 2.8, width: radius * 5.6, height: radius * 5.6))
        ctx.fill(halo, with: .color(color.opacity(alpha * 0.20)))
        // Mid glow
        let mid = Path(ellipseIn: CGRect(x: cx - radius * 1.7, y: cy - radius * 1.7, width: radius * 3.4, height: radius * 3.4))
        ctx.fill(mid, with: .color(color.opacity(alpha * 0.45)))
        // Core
        let core = Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
        ctx.fill(core, with: .color(color.opacity(alpha * 0.95)))
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.placeholderBgTop, Color.placeholderBgBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        CookingSteamLoaderView()
    }
    .frame(width: 320, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
