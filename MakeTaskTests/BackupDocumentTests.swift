import Foundation
import XCTest
@testable import MakeTask

@MainActor
final class BackupDocumentTests: XCTestCase {
    func testRoundTripThroughLocalBackupService() throws {
        let original = BackupFixtures.document()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MakeTaskBackup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let encoded = try LocalBackupService.encode(original)
        try encoded.write(to: url, options: .atomic)
        let decoded = try LocalBackupService.decode(contentsOf: url)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.taskCount, 1)
        XCTAssertEqual(decoded.subtaskCount, 1)
    }

    func testNewerBackupFormatIsRejected() {
        let document = BackupFixtures.document(
            formatVersion: MakeTaskBackupDocument.currentFormatVersion + 1
        )

        XCTAssertThrowsError(try document.validate()) { error in
            XCTAssertEqual(
                error as? MakeTaskBackupError,
                .newerFormat(MakeTaskBackupDocument.currentFormatVersion + 1)
            )
        }
    }

    func testDuplicateTaskIdentifiersAreRejected() {
        let taskID = UUID()
        let original = BackupFixtures.document(taskID: taskID)
        let list = original.lists[0]
        let duplicateTask = MakeTaskBackupDocument.TaskRecord(
            id: taskID,
            title: "Duplicate",
            notes: "",
            dueDate: nil,
            priority: 0,
            isCompleted: false,
            completedAt: nil,
            createdAt: BackupFixtures.date,
            sortOrder: 1,
            subtasks: []
        )
        let duplicateList = MakeTaskBackupDocument.ListRecord(
            id: list.id,
            title: list.title,
            colorRawValue: list.colorRawValue,
            sortOrder: list.sortOrder,
            createdAt: list.createdAt,
            windowX: list.windowX,
            windowTop: list.windowTop,
            windowWidth: list.windowWidth,
            windowHeight: list.windowHeight,
            isCollapsed: list.isCollapsed,
            isCompletedSectionCollapsed: list.isCompletedSectionCollapsed,
            isHidden: list.isHidden,
            windowModeRawValue: list.windowModeRawValue,
            tasks: list.tasks + [duplicateTask]
        )
        let document = MakeTaskBackupDocument(
            exportedAt: original.exportedAt,
            sourceAppVersion: original.sourceAppVersion,
            defaultListID: duplicateList.id,
            lastQuickCaptureListID: duplicateList.id,
            lists: [duplicateList]
        )

        XCTAssertThrowsError(try document.validate()) { error in
            XCTAssertEqual(error as? MakeTaskBackupError, .duplicateIdentifier)
        }
    }

    func testUnknownDefaultListIsRejected() {
        let original = BackupFixtures.document()
        let document = MakeTaskBackupDocument(
            exportedAt: original.exportedAt,
            sourceAppVersion: original.sourceAppVersion,
            defaultListID: UUID(),
            lastQuickCaptureListID: original.lastQuickCaptureListID,
            lists: original.lists
        )

        XCTAssertThrowsError(try document.validate()) { error in
            XCTAssertEqual(error as? MakeTaskBackupError, .invalidDefaultList)
        }
    }

    func testMalformedJSONIsRejectedWithoutCrashing() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("InvalidMakeTaskBackup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("{ not-json".utf8).write(to: url)

        XCTAssertThrowsError(try LocalBackupService.decode(contentsOf: url)) { error in
            XCTAssertEqual(error as? MakeTaskBackupError, .invalidJSON)
        }
    }
}
