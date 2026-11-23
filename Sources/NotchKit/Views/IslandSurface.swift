import SwiftUI

/// The black shapes behind the content: the main shape and the minimal bubble. Drawn in a Canvas
/// so the two can merge like liquid while they move.
struct IslandSurface: View, Animatable {
    var layout: IslandLayout
    /// Liquid pulse from the transition keyframes, 0…1.
    var pulse: Double
    var liquid: Bool
    var brutal = false
    /// The playing song's colour, from its artwork.
    var songColor: Color?

    @Environment(\.displayScale) private var displayScale

    nonisolated var animatableData: AnimatableVector {
        get { layout.animatableData }
        set { layout.animatableData = newValue }
    }

    var body: some View {
        let strength = liquid ? min(1, pulse) : 0
        Group {
            if GooMath.blurRadius(strength: strength) > 0.2 {
                liquidCanvas(strength: strength)
            } else {
                plainShapes
            }
        }
        // One shadow for the whole group, not one per shape inside it.
        .compositingGroup()
        // Brutal has its own hard shadow; a soft one under it would blur the look.
        .shadow(color: brutal ? .clear : glowColor, radius: songColor == nil ? 18 : 14, y: songColor == nil ? 8 : 3)
        .animation(.smooth(duration: 0.6), value: songColor)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A soft black shadow, or a glow of the song's colour that reads even under a closed notch.
    private var glowColor: Color {
        if let songColor { return songColor.opacity(0.55) }
        return .black.opacity(0.35 * min(layout.shadow, 1))
    }

    /// Most of the time: plain black shapes, which the graphics card draws as they move.
    private var plainShapes: some View {
        let opacity = min(1, layout.pillOpacity * 20)
        let hasBubble = layout.bubble.width > 0.5 && layout.bubble.height > 0.5
        let edge = brutal ? layout.brutalEdge : 0
        let offset = BrutalPalette.shadowOffset * layout.contentScale * edge
        return ZStack(alignment: .topLeading) {
            if edge > 0.001 {
                // A copy of the shape, solid and unblurred, pushed down and right.
                IslandShape(topRadius: layout.topRadius, bottomRadius: layout.bottomRadius, flare: layout.flare)
                    .fill((songColor ?? BrutalPalette.shadow).opacity(edge))
                    .frame(width: max(layout.pill.width, 1), height: max(layout.pill.height, 1))
                    .offset(x: layout.pill.minX + offset, y: layout.pill.minY + offset)
            }
            IslandShape(topRadius: layout.topRadius, bottomRadius: layout.bottomRadius, flare: layout.flare)
                .fill(Color.black.opacity(opacity))
                .frame(width: max(layout.pill.width, 1), height: max(layout.pill.height, 1))
                .offset(x: layout.pill.minX, y: layout.pill.minY)
                .opacity(opacity > 0.001 ? 1 : 0)
            if hasBubble {
                layout.bubblePath
                    .fill(Color.black)
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .topLeading)
    }

    /// Only while the bubble splits off or merges back: the liquid "goo", which needs a blur
    /// and an alpha threshold over both shapes, so it's drawn into a canvas.
    private func liquidCanvas(strength: Double) -> some View {
        let layout = layout
        let scale = displayScale
        return Canvas(opaque: false, rendersAsynchronously: false) { context, _ in
            let main = IslandPath.path(in: layout.pill, topRadius: layout.topRadius, bottomRadius: layout.bottomRadius, flare: layout.flare)
            // The shape stays solid while it moves and only vanishes once it is back inside the
            // notch (or the top edge), instead of fading in and out.
            let opacity = min(1, layout.pillOpacity * 20)
            guard opacity > 0.001 || layout.bubble.width > 0.5 else { return }
            let mainShading = GraphicsContext.Shading.color(Color.black.opacity(opacity))
            let black = GraphicsContext.Shading.color(Color.black)
            let hasBubble = layout.bubble.width > 0.5 && layout.bubble.height > 0.5
            let blur = GooMath.blurRadius(strength: strength)

            guard blur > 0.2 else {
                context.fill(main, with: mainShading)
                if hasBubble {
                    context.fill(layout.bubblePath, with: black)
                }
                return
            }

            context.drawLayer { goo in
                let slope = GooMath.alphaSlope(blurRadius: blur, displayScale: scale)
                var matrix = ColorMatrix()
                matrix.a4 = Float(slope)
                matrix.a5 = Float(GooMath.alphaBias(slope: slope))
                // Filters apply in reverse order: blur first, then the alpha sharpen.
                goo.addFilter(.colorMatrix(matrix))
                goo.addFilter(.blur(radius: blur))
                goo.drawLayer { layer in
                    layer.fill(main, with: mainShading)
                    if hasBubble {
                        layer.fill(layout.bubblePath, with: black)
                    }
                }
            }
            // The blur softens edges that touch the screen top; a crisp copy keeps them sharp.
            context.fill(main, with: mainShading)
            if hasBubble {
                context.fill(layout.bubblePath, with: black)
            }
        }
    }
}

/// Clip and hit shape for the content, matching the drawn surface.
struct IslandShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var flare: CGFloat

    nonisolated var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(topRadius, AnimatablePair(bottomRadius, flare)) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second.first
            flare = newValue.second.second
        }
    }

    nonisolated func path(in rect: CGRect) -> Path {
        IslandPath.path(in: rect, topRadius: topRadius, bottomRadius: bottomRadius, flare: flare)
    }
}
