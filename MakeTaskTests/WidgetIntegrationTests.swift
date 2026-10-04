import AppKit
import SwiftData
import SwiftUI
import WidgetKit
import XCTest
@testable import MakeTask

@MainActor
final class WidgetIntegrationTests: XCTestCase {
    func testCompletionIntentUsesTheExistingHostCoordinator() async throws {
        let env = try TestEnvironment()
        let previous = WidgetActionDispatcher.coordinator
        defer {
            WidgetActionDispatcher.coordinator = previous
            env.coordinator.stop()
            env.cleanUp()
        }
        let list = TodoList(title: "Intent target")
        let task = TodoTask(title: "Complete through intent", list: list)
        env.container.mainContext.insert(list)
        env.container.mainContext.insert(task)
        try env.container.mainContext.save()
        WidgetActionDispatcher.coordinator = env.coordinator
        _ = try await SetWidgetTaskCompletion(taskID: task.id, completed: true).perform()
        XCTAssertTrue(task.isCompleted)
        XCTAssertTrue(env.coordinator.canUndo)
        XCTAssertFalse(env.container.mainContext.hasChanges)
    }

    func testCompletionIsIdempotentAndSupportsUndoRedo() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp(); env.coordinator.stop() }
        let list = TodoList(title: "Today")
        let task = TodoTask(title: "Ship", list: list)
        env.container.mainContext.insert(list)
        env.container.mainContext.insert(task)
        try env.container.mainContext.save()
        var snapshots: [WidgetSnapshot] = []
        env.coordinator.onWidgetRefresh = { snapshots.append(try WidgetBridge.snapshot(context: env.container.mainContext)) }

        try env.coordinator.setTaskCompletionFromWidget(id: task.id, completed: true)
        let completionDate = task.completedAt
        try env.coordinator.setTaskCompletionFromWidget(id: task.id, completed: true)
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(task.completedAt, completionDate)
        XCTAssertTrue(snapshots.last!.lists[0].tasks[0].isCompleted)
        XCTAssertTrue(env.coordinator.undoLastAction())
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
        XCTAssertFalse(env.coordinator.canUndo, "Repeated delivery must not add a second undo action")
        XCTAssertFalse(snapshots.last!.lists[0].tasks[0].isCompleted)
        XCTAssertTrue(env.coordinator.redoLastAction())
        XCTAssertTrue(task.isCompleted)
        try env.coordinator.setTaskCompletionFromWidget(id: task.id, completed: false)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
    }

    func testFailedCompletionDoesNotPublishOrChangeTheTask() throws {
        var shouldFail = false
        let env = try TestEnvironment(saveChanges: { context in
            if shouldFail { throw CocoaError(.fileWriteNoPermission) }
            try context.save()
        })
        defer { env.cleanUp(); env.coordinator.stop() }
        let list = TodoList(title: "Today")
        let task = TodoTask(title: "Keep me", list: list)
        env.container.mainContext.insert(list)
        env.container.mainContext.insert(task)
        try env.container.mainContext.save()
        var publishCount = 0
        env.coordinator.onWidgetRefresh = { publishCount += 1 }
        shouldFail = true
        XCTAssertThrowsError(try env.coordinator.setTaskCompletionFromWidget(id: task.id, completed: true))
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(publishCount, 0)
        XCTAssertFalse(env.coordinator.canUndo)
        XCTAssertNotNil(env.coordinator.persistenceError)
        shouldFail = false
        env.coordinator.saveContext()
        XCTAssertNil(env.coordinator.persistenceError)
    }

    func testDeletedTaskCannotBeResurrectedByStaleWidget() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp() }
        var refreshed = false
        env.coordinator.onWidgetRefresh = { refreshed = true }
        XCTAssertThrowsError(try env.coordinator.setTaskCompletionFromWidget(id: UUID(), completed: true))
        XCTAssertTrue(refreshed)
        XCTAssertEqual(try env.container.mainContext.fetchCount(FetchDescriptor<TodoTask>()), 0)
    }

    func testSnapshotTracksRenameCompletionDeletionAndExcludesPrivateNotes() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp(); env.coordinator.stop() }
        let list = TodoList(title: "Later", color: .teal, isHidden: true)
        let task = TodoTask(title: "Visible", notes: "private detail", sortOrder: 2, list: list)
        let earlier = TodoTask(title: "First", sortOrder: 1, list: list)
        env.container.mainContext.insert(list)
        env.container.mainContext.insert(task)
        env.container.mainContext.insert(earlier)
        var published: WidgetSnapshot?
        env.coordinator.onWidgetRefresh = { published = try WidgetBridge.snapshot(context: env.container.mainContext) }
        env.coordinator.saveContext()
        XCTAssertEqual(published?.lists[0].tasks.map(\.title), ["First", "Visible"])
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(published), as: UTF8.self).contains("private detail"))
        list.title = "Renamed"
        env.coordinator.saveContext()
        XCTAssertEqual(published?.lists[0].title, "Renamed")
        env.coordinator.deleteTask(task)
        XCTAssertEqual(published?.lists[0].tasks.count, 1)
        XCTAssertTrue(env.coordinator.undoLastAction())
        XCTAssertEqual(published?.lists[0].tasks.count, 2)
        env.container.mainContext.delete(list)
        env.coordinator.saveContext()
        XCTAssertEqual(published?.lists.count, 0)
    }

    func testAtomicSnapshotStoreAndVersionValidation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WidgetSnapshotStore(url: directory.appendingPathComponent("snapshot.json"))
        XCTAssertNil(try store.read())
        let snapshot = WidgetSnapshot(lists: [TaskWidgetEntry.preview.list!])
        XCTAssertTrue(try store.write(snapshot))
        XCTAssertEqual(try store.read(), snapshot)
        XCTAssertFalse(try store.write(snapshot))
        XCTAssertTrue(try store.write(WidgetSnapshot(lists: [])))
        XCTAssertEqual(try store.read()?.lists, [])
        var unsupported = snapshot
        unsupported.version = 99
        try JSONEncoder().encode(unsupported).write(to: store.url)
        XCTAssertThrowsError(try store.read())
        try Data("broken".utf8).write(to: store.url)
        XCTAssertThrowsError(try store.read())
    }

    func testConfiguredDeletedListDoesNotFallBackAndCompletedFilterWorks() {
        let list = TaskWidgetEntry.preview.list!
        let snapshot = WidgetSnapshot(lists: [list])
        XCTAssertEqual(snapshot.list(id: nil)?.id, list.id)
        XCTAssertNil(snapshot.list(id: UUID()))
        XCTAssertEqual(list.visibleTasks(showCompleted: false).count, 2)
        XCTAssertEqual(list.visibleTasks(showCompleted: true).last?.isCompleted, true)
        XCTAssertEqual(list.remainingCount, 2)
    }

    func testRoutesRoundTripAndRejectMalformedOrMutatingURLs() {
        let id = UUID()
        for route: WidgetRoute in [.home, .add(nil), .add(id), .list(id), .task(id)] {
            XCTAssertEqual(WidgetRoute(url: route.url), route)
        }
        for value in ["https://task/\(id)", "maketask://delete/\(id)", "maketask://task/nope",
                      "maketask://task/\(id)/extra", "maketask://open?delete=all", "maketask://user@open"] {
            XCTAssertNil(WidgetRoute(url: URL(string: value)!))
        }
    }

    func testWidgetSyncFailureIsSeparateFromDatabaseFailure() throws {
        let env = try TestEnvironment()
        defer { env.cleanUp() }
        env.coordinator.onWidgetRefresh = { throw WidgetDataError.unavailable }
        env.container.mainContext.insert(TodoList(title: "Saved safely"))
        env.coordinator.saveContext()
        XCTAssertNotNil(env.coordinator.widgetError)
        XCTAssertNil(env.coordinator.persistenceError)
        XCTAssertFalse(env.container.mainContext.hasChanges)
        env.coordinator.onWidgetRefresh = {}
        env.coordinator.refreshWidgets()
        XCTAssertNil(env.coordinator.widgetError)
    }

    func testWidgetAddSelectsItsOwnList() throws {
        let env = try TestEnvironment()
        defer { env.coordinator.dismissQuickAdd(); env.coordinator.stop(); env.cleanUp() }
        let first = TodoList(title: "First")
        let target = TodoList(title: "Widget list")
        env.container.mainContext.insert(first)
        env.container.mainContext.insert(target)
        try env.container.mainContext.save()
        env.settings.lastQuickCaptureListID = first.id
        env.coordinator.handleWidgetRoute(.add(target.id))
        XCTAssertEqual(env.settings.lastQuickCaptureListID, target.id)
    }

    func testWidgetViewsRenderAllSizesAndStates() throws {
        let sizes: [(WidgetFamily, CGFloat, CGFloat)] = [(.systemSmall, 170, 170), (.systemMedium, 360, 170), (.systemLarge, 360, 380)]
        let preview = TaskWidgetEntry.preview
        let states = [preview,
                      TaskWidgetEntry(date: .now, list: nil, showCompleted: false, message: "Open MakeTask to load your lists."),
                      TaskWidgetEntry(date: .now, list: WidgetListSnapshot(id: UUID(), title: "Empty", color: "teal", tasks: []), showCompleted: false, message: "")]
        for (family, width, height) in sizes {
            for (index, entry) in states.enumerated() {
                let view = TaskWidgetView(entry: entry, family: family)
                    .padding(16).frame(width: width, height: height).background(Color(nsColor: .windowBackgroundColor))
                let host = NSHostingView(rootView: view)
                host.frame = NSRect(x: 0, y: 0, width: width, height: height)
                let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = host
                window.orderFront(nil)
                defer { window.close() }
                host.layoutSubtreeIfNeeded()
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                XCTAssertGreaterThan(bitmap.pixelsWide, 0)
                if index == 0, let png = bitmap.representation(using: .png, properties: [:]) {
                    let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
                    attachment.name = "Widget \(Int(width))×\(Int(height))"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
            }
        }
    }
}
