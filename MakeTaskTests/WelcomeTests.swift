import AppKit
import SwiftData
import XCTest
@testable import MakeTask

@MainActor
final class WelcomeTests: XCTestCase {
    func testFirstLaunchShowsWelcomeWithoutCreatingDataAndDismissalPersists() throws {
        let environment = try TestEnvironment()
        defer { environment.coordinator.dismissWelcome(); environment.cleanUp() }
        XCTAssertFalse(environment.settings.hasCompletedWelcome)
        environment.coordinator.presentWelcomeIfNeeded()
        XCTAssertTrue(NSApp.windows.contains { $0.identifier?.rawValue == "maketask.welcome" && $0.isVisible })
        XCTAssertEqual(try environment.container.mainContext.fetchCount(FetchDescriptor<TodoList>()), 0)
        environment.coordinator.dismissWelcome()
        XCTAssertTrue(AppSettings(defaults: environment.defaults).hasCompletedWelcome)
        environment.coordinator.presentWelcomeIfNeeded()
        XCTAssertFalse(NSApp.windows.contains { $0.identifier?.rawValue == "maketask.welcome" && $0.isVisible })
    }

    func testExistingHiddenListSkipsWelcomeAndStaysHidden() throws {
        let environment = try TestEnvironment()
        defer { environment.coordinator.dismissWelcome(); environment.cleanUp() }
        let list = TodoList(title: "Existing", isHidden: true)
        environment.container.mainContext.insert(list)
        try environment.container.mainContext.save()
        environment.coordinator.presentWelcomeIfNeeded()
        XCTAssertTrue(list.isHidden)
        XCTAssertTrue(environment.settings.hasCompletedWelcome)
        XCTAssertFalse(NSApp.windows.contains { $0.identifier?.rawValue == "maketask.welcome" && $0.isVisible })
        XCTAssertEqual(try environment.container.mainContext.fetchCount(FetchDescriptor<TodoList>()), 1)
    }

    func testWelcomeCreatesNamedListAndRejectsBlankName() throws {
        let environment = try TestEnvironment()
        defer { environment.coordinator.dismissWelcome(); environment.coordinator.hideAll(); environment.cleanUp() }
        XCTAssertNil(environment.coordinator.createListFromWelcome(title: "  \n "))
        XCTAssertFalse(environment.settings.hasCompletedWelcome)
        let list = try XCTUnwrap(environment.coordinator.createListFromWelcome(title: "  Reading  "))
        XCTAssertEqual(list.title, "Reading")
        XCTAssertFalse(list.isHidden)
        XCTAssertTrue(environment.settings.hasCompletedWelcome)
        XCTAssertEqual(environment.coordinator.activeListID, list.id)
        let context = ModelContext(environment.container)
        XCTAssertEqual(try context.fetch(FetchDescriptor<TodoList>()).map(\.title), ["Reading"])
    }
}
