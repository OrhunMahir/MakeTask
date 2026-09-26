import AppKit
import XCTest
@testable import MakeTask

final class NoteScreenGeometryTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 40, width: 1200, height: 760)

    func testReachableFrameStaysUnchangedAndEdgeSliversAreRecovered() throws {
        let reachable = NSRect(x: 200, y: 300, width: 320, height: 360)
        XCTAssertEqual(NoteScreenGeometry.fit(reachable, to: [screen])?.frame, reachable)
        for origin in [NSPoint(x: 1199, y: 300), NSPoint(x: -319, y: 300),
                       NSPoint(x: 200, y: 799), NSPoint(x: 200, y: -319)] {
            let frame = NSRect(origin: origin, size: reachable.size)
            let placement = try XCTUnwrap(NoteScreenGeometry.fit(frame, to: [screen]))
            XCTAssertTrue(screen.contains(placement.frame))
            XCTAssertEqual(placement.frame.size, reachable.size)
        }
    }

    func testOversizedFrameShrinksToVisibleAreaAndKeepsTopWhenPossible() throws {
        let wide = NSRect(x: -100, y: 200, width: 2000, height: 360)
        let placement = try XCTUnwrap(NoteScreenGeometry.fit(wide, to: [screen]))
        XCTAssertEqual(placement.frame.width, screen.width)
        XCTAssertEqual(placement.frame.maxY, wide.maxY)
        XCTAssertEqual(placement.frame.height, wide.height)
        let oversized = NSRect(x: -500, y: -500, width: 3000, height: 2000)
        XCTAssertEqual(NoteScreenGeometry.fit(oversized, to: [screen])?.frame, screen)
    }

    func testUsesLargestOverlapOrNearestRemainingMonitorWithNegativeCoordinates() throws {
        let left = NSRect(x: -1280, y: 40, width: 1280, height: 900)
        let crossing = NSRect(x: -280, y: 300, width: 320, height: 360)
        let overlapping = try XCTUnwrap(NoteScreenGeometry.fit(crossing, to: [screen, left]))
        XCTAssertEqual(overlapping.visibleFrame, left)
        XCTAssertTrue(left.contains(overlapping.frame))
        let disconnected = NSRect(x: -2500, y: 300, width: 320, height: 360)
        let recovered = try XCTUnwrap(NoteScreenGeometry.fit(disconnected, to: [screen, left]))
        XCTAssertEqual(recovered.visibleFrame, left)
        XCTAssertTrue(left.contains(recovered.frame))
    }

    func testCollapsedHeaderFitsAboveDockAndBelowMenuBar() throws {
        for top: CGFloat in [50, 900] {
            let frame = NSRect(x: 200, y: top - 34, width: 320, height: 34)
            let placement = try XCTUnwrap(NoteScreenGeometry.fit(frame, to: [screen]))
            XCTAssertTrue(screen.contains(placement.frame))
            XCTAssertEqual(placement.frame.height, 34)
        }
    }

    func testTransientMissingOrInvalidScreensDoNotSupplyAPlacement() {
        let frame = NSRect(x: 200, y: 300, width: 320, height: 360)
        XCTAssertNil(NoteScreenGeometry.fit(frame, to: []))
        XCTAssertNil(NoteScreenGeometry.fit(frame, to: [.zero]))
        XCTAssertEqual(NoteScreenGeometry.fit(frame, to: [.zero, screen])?.frame, frame)
    }
}
