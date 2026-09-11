import AppKit

/// Shared by restoration, display changes and expansion. All coordinates are
/// AppKit screen coordinates; visible frames exclude the menu bar and Dock.
enum NoteScreenGeometry {
    @MainActor
    static var currentVisibleFrames: [NSRect] {
        let screens = NSScreen.screens
        guard let main = NSScreen.main else { return screens.map(\.visibleFrame) }
        // Preserve creation on the active display; geometry chooses other
        // displays by overlap or distance when restoring existing notes.
        return [main.visibleFrame] + screens.filter { $0 != main }.map(\.visibleFrame)
    }

    struct Placement {
        let frame: NSRect
        let visibleFrame: NSRect
    }

    static func fit(_ frame: NSRect, to visibleFrames: [NSRect]) -> Placement? {
        let screens = visibleFrames.filter {
            $0.minX.isFinite && $0.minY.isFinite && $0.width.isFinite && $0.height.isFinite
                && $0.width > 0 && $0.height >= NoteWindowMetrics.headerHeight
        }
        guard let first = screens.first else { return nil }
        let proposed = NSRect(
            x: frame.minX.isFinite ? frame.minX : first.minX,
            y: frame.minY.isFinite ? frame.minY : first.minY,
            width: frame.width.isFinite && frame.width > 0 ? frame.width : NoteWindowMetrics.defaultWidth,
            height: frame.height.isFinite && frame.height > 0 ? frame.height : NoteWindowMetrics.defaultHeight
        )
        func intersectionArea(_ screen: NSRect) -> CGFloat {
            let intersection = screen.intersection(proposed)
            return intersection.isNull ? 0 : intersection.width * intersection.height
        }
        func distanceSquared(_ screen: NSRect) -> CGFloat {
            let dx = max(screen.minX - proposed.midX, proposed.midX - screen.maxX, 0)
            let dy = max(screen.minY - proposed.midY, proposed.midY - screen.maxY, 0)
            return dx * dx + dy * dy
        }
        // Keep the display holding most of the note. If its display disappeared,
        // choose the nearest remaining one, with input order as a stable tie-break.
        var screen = first
        for candidate in screens.dropFirst() {
            let area = intersectionArea(candidate)
            let bestArea = intersectionArea(screen)
            if area > bestArea || (area == bestArea && distanceSquared(candidate) < distanceSquared(screen)) {
                screen = candidate
            }
        }
        let width = min(max(proposed.width, NoteWindowMetrics.minimumWidth), screen.width)
        let height = min(proposed.height, screen.height)
        // Preserve the top edge when reducing height, then clamp the whole frame.
        let x = min(max(proposed.minX, screen.minX), screen.maxX - width)
        let top = min(max(proposed.maxY, screen.minY + height), screen.maxY)
        return Placement(
            frame: NSRect(x: x, y: top - height, width: width, height: height),
            visibleFrame: screen
        )
    }
}
