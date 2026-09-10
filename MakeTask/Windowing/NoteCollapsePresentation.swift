import AppKit
import Observation
import QuartzCore

@MainActor
@Observable
final class NoteCollapsePresentation {
    enum Phase {
        case expanded, expanding, collapsed, collapsing
    }

    var phase: Phase
    var showsBody: Bool { phase == .expanded }
    var collapsedChrome: Bool { phase == .collapsed || phase == .expanding }

    init(collapsed: Bool) {
        phase = collapsed ? .collapsed : .expanded
    }
}

/// One clock owns the window geometry. SwiftUI does not animate the header layout.
@MainActor
protocol NoteCollapseAnimationDriving: AnyObject {
    func start(update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void)
}

@MainActor
final class NoteCollapseAnimationDriver: NoteCollapseAnimationDriving {
    private var timer: Timer?

    func start(update: @escaping (CGFloat) -> Void, completion: @escaping () -> Void) {
        timer?.invalidate()
        let start = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard self != nil else { timer.invalidate(); return }
                let fraction = min((CACurrentMediaTime() - start) / 0.18, 1)
                // Smooth endpoints, with a fixed top edge at every sample.
                update(fraction * fraction * (3 - 2 * fraction))
                if fraction >= 1 {
                    timer.invalidate()
                    self?.timer = nil
                    completion()
                }
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
