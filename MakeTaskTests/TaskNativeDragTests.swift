import AppKit
import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class TaskNativeDragTests: XCTestCase {
    func testNativeViewportReordersHostedRowsWhileHoveringAndCommitsOneUndo() throws {
        let environment = try TestEnvironment()
        defer { environment.cleanUp() }
        let list = TodoList(title: "Drag test")
        environment.container.mainContext.insert(list)
        let tasks = ["Alpha", "Beta", "Gamma"].enumerated().map {
            TodoTask(title: $0.element, sortOrder: Double($0.offset), list: list)
        }
        tasks.forEach(environment.container.mainContext.insert)
        try environment.container.mainContext.save()
        let controller = NoteWindowController(
            list: list, frame: NSRect(x: 200, y: 300, width: 320, height: 360),
            modelContainer: environment.container, coordinator: environment.coordinator, settings: environment.settings
        )
        defer { controller.close() }
        let window = try XCTUnwrap(controller.window)
        window.orderFront(nil)
        settle(window)
        let destination = try XCTUnwrap(descendants(window.contentView!).compactMap { $0 as? TaskDropDestinationNSView }.first)
        XCTAssertNil(destination.hitTest(NSPoint(x: 50, y: 50)))
        XCTAssertGreaterThan(destination.bounds.height, 100)
        let source = try XCTUnwrap(descendants(window.contentView!).compactMap { $0 as? TaskDragSourceNSView }.first { $0.taskID == tasks[2].id })
        environment.coordinator.beginTaskDrag(tasks[2])
        settle(window)
        XCTAssertEqual(destination.draggedTaskID, tasks[2].id)
        let drag = DragInfo(source: source, window: window, id: tasks[2].id)
        drag.draggingLocation = destination.convert(NSPoint(x: 100, y: 8), to: nil)
        XCTAssertEqual(destination.draggingEntered(drag), .move)
        settle(window)
        XCTAssertEqual(list.orderedTasks.map(\.title), ["Gamma", "Alpha", "Beta"], "The gap moves before the mouse is released")
        for _ in 0..<5 { XCTAssertEqual(destination.draggingUpdated(drag), .move); settle(window) }
        XCTAssertEqual(list.orderedTasks.map(\.title), ["Gamma", "Alpha", "Beta"], "A stationary pointer must not oscillate")
        XCTAssertTrue(destination.prepareForDragOperation(drag))
        XCTAssertTrue(destination.performDragOperation(drag))
        // The native source also ends the session after the destination commits it.
        environment.coordinator.endTaskDrag()
        settle(window)
        XCTAssertNil(destination.draggedTaskID)
        XCTAssertTrue(environment.coordinator.undoLastAction())
        XCTAssertEqual(list.orderedTasks.map(\.title), ["Alpha", "Beta", "Gamma"])
        XCTAssertFalse(environment.coordinator.canUndo)
        XCTAssertTrue(environment.coordinator.redoLastAction())
        XCTAssertEqual(list.orderedTasks.map(\.title), ["Gamma", "Alpha", "Beta"])
    }

    func testNativeDestinationRejectsForeignOrStalePayloadsAndOutsidePoints() {
        let destination = TaskDropDestinationNSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let window = NSWindow(contentRect: destination.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = destination
        defer { window.close() }
        let id = UUID()
        destination.draggedTaskID = id
        let drag = DragInfo(source: TaskDragSourceNSView(), window: window, id: UUID())
        drag.draggingLocation = destination.convert(NSPoint(x: 100, y: 50), to: nil)
        var hovers = 0
        destination.onHover = { _, _ in hovers += 1 }
        XCTAssertEqual(destination.draggingEntered(drag), [])
        drag.draggingPasteboard.setString(id.uuidString, forType: .makeTaskID)
        drag.draggingSource = nil
        XCTAssertFalse(destination.performDragOperation(drag))
        drag.draggingSource = TaskDragSourceNSView()
        drag.draggingLocation = destination.convert(NSPoint(x: -5, y: 50), to: nil)
        XCTAssertEqual(destination.draggingUpdated(drag), [])
        XCTAssertEqual(hovers, 0)
        drag.draggingLocation = destination.convert(NSPoint(x: 100, y: 50), to: nil)
        XCTAssertEqual(destination.draggingUpdated(drag), .move)
        XCTAssertEqual(hovers, 1)
    }

    func testNativeDestinationScrollsNearEdges() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let window = NSWindow(contentRect: root.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = root
        defer { window.close() }
        let scroll = NSScrollView(frame: root.bounds)
        let document = FlippedView(frame: NSRect(x: 0, y: 0, width: 320, height: 1200))
        scroll.documentView = document
        root.addSubview(scroll)
        let destination = TaskDropDestinationNSView(frame: root.bounds)
        root.addSubview(destination)
        let id = UUID()
        destination.draggedTaskID = id
        let drag = DragInfo(source: TaskDragSourceNSView(), window: window, id: id)
        drag.draggingLocation = destination.convert(NSPoint(x: 100, y: 198), to: nil)
        XCTAssertEqual(destination.draggingUpdated(drag), .move)
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)
        XCTAssertTrue(destination.wantsPeriodicDraggingUpdates())
    }

    private func settle(_ window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class DragInfo: NSObject, @preconcurrency NSDraggingInfo {
    var draggingDestinationWindow: NSWindow?
    var draggingSourceOperationMask: NSDragOperation = .move
    var draggingLocation: NSPoint = .zero
    var draggedImageLocation: NSPoint = .zero
    var draggedImage: NSImage? { nil }
    let draggingPasteboard = NSPasteboard.withUniqueName()
    var draggingSource: Any?
    var draggingSequenceNumber: Int = 1
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight = .none

    init(source: TaskDragSourceNSView, window: NSWindow, id: UUID) {
        draggingSource = source
        draggingDestinationWindow = window
        super.init()
        draggingPasteboard.setString(id.uuidString, forType: .makeTaskID)
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any], using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
