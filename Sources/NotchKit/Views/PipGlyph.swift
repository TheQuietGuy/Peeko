import AppKit

/// Peeko's menu bar icon: a tiny notch with Pip's two eyes cut out of it. A template image,
/// so macOS tints it for a light or dark menu bar like its own icons.
enum PipGlyph {
    static func menuBarImage(asleep: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 16), flipped: false) { rect in
            // The notch: flat along the top, round underneath, hanging from the top edge.
            let body = NSRect(x: 1, y: 4, width: rect.width - 2, height: 10)
            let path = NSBezierPath(roundedRect: body, xRadius: 5, yRadius: 5)
            path.append(NSBezierPath(rect: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2)))
            path.windingRule = .nonZero
            NSColor.black.setFill()
            path.fill()
            // Eyes, cut out so the menu bar shows through.
            NSGraphicsContext.current?.compositingOperation = .clear
            for x in [body.minX + 4, body.maxX - 7] {
                let eye = asleep
                    ? NSBezierPath(roundedRect: NSRect(x: x, y: 7.5, width: 3, height: 1.6), xRadius: 0.8, yRadius: 0.8)
                    : NSBezierPath(roundedRect: NSRect(x: x, y: 6, width: 3, height: 5.5), xRadius: 1.5, yRadius: 1.5)
                eye.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Peeko"
        return image
    }
}
