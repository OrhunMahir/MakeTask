import Foundation

enum NoteNavigationDirection: CaseIterable {
    case left, right, up, down
}

enum NoteNavigation {
    struct Candidate {
        let id: UUID
        let frame: CGRect
    }

    /// Compare header positions: expanding a note must not change which row it
    /// belongs to. AppKit screen coordinates increase upward, across all displays.
    static func neighbor(from source: CGRect, in direction: NoteNavigationDirection,
                         candidates: [Candidate]) -> UUID? {
        let ranked = candidates.compactMap { candidate -> (UUID, CGFloat)? in
            let dx = candidate.frame.midX - source.midX
            let dy = candidate.frame.maxY - source.maxY
            let forward: CGFloat
            let sideways: CGFloat
            switch direction {
            case .left: forward = -dx; sideways = abs(dy)
            case .right: forward = dx; sideways = abs(dy)
            case .up: forward = dy; sideways = abs(dx)
            case .down: forward = -dy; sideways = abs(dx)
            }
            // Ignore tiny layout differences and notes mainly in another
            // direction. Favor nearby notes aligned with the requested arrow.
            guard forward > 1, forward >= sideways else { return nil }
            return (candidate.id, forward * forward + 2 * sideways * sideways)
        }
        return ranked.min {
            $0.1 == $1.1 ? $0.0.uuidString < $1.0.uuidString : $0.1 < $1.1
        }?.0
    }
}
