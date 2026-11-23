import CoreGraphics

/// Decides whether the app in front is full screen on a display, from its on-screen windows.
/// A full-screen window covers the whole display, menu bar strip included; a zoomed window
/// stops below the menu bar, so it doesn't count.
public enum FullScreenDetector {
    /// One window as `CGWindowListCopyWindowInfo` reports it: top-left origin, global points.
    public struct Window: Equatable, Sendable {
        public var ownerPID: Int32
        public var layer: Int
        public var bounds: CGRect

        public init(ownerPID: Int32, layer: Int, bounds: CGRect) {
            self.ownerPID = ownerPID
            self.layer = layer
            self.bounds = bounds
        }
    }

    /// `display` in the same top-left coordinates as the windows.
    public static func isFullScreen(frontmostPID: Int32, windows: [Window], display: CGRect) -> Bool {
        windows.contains { window in
            window.ownerPID == frontmostPID
                && window.layer == 0
                && window.bounds.insetBy(dx: 1, dy: 1).contains(display.insetBy(dx: 2, dy: 2))
        }
    }

    /// Converts an AppKit screen frame (bottom-left origin) to window-list coordinates
    /// (top-left origin of the primary display).
    public static func windowListRect(forScreenFrame frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
