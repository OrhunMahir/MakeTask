import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class LocalBackupService: ObservableObject {
    struct Notice: Identifiable, Equatable {
        enum Kind {
            case success
            case error
        }

        let id = UUID()
        let kind: Kind
        let title: String
        let message: String
    }

    @Published var notice: Notice?
    @Published private(set) var isWorking = false

    private unowned let coordinator: WindowCoordinator

    init(coordinator: WindowCoordinator) {
        self.coordinator = coordinator
    }

    func chooseExportLocation() {
        let panel = NSSavePanel()
        panel.title = "Export MakeTask Backup"
        panel.prompt = "Export"
        panel.nameFieldStringValue = Self.defaultFileName
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportBackup(to: url)
    }

    func chooseBackupToImport() {
        let panel = NSOpenPanel()
        panel.title = "Import MakeTask Backup"
        panel.prompt = "Import"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        importBackup(from: url)
    }

    func exportBackup(to url: URL) {
        isWorking = true
        defer { isWorking = false }

        do {
            let document = try coordinator.makeBackupDocument()
            let data = try Self.encode(document)
            try withSecurityScopedAccess(to: url) {
                try data.write(to: url, options: .atomic)
            }
            notice = Notice(
                kind: .success,
                title: "Backup Exported",
                message: "Exported \(document.lists.count) lists, \(document.taskCount) tasks, and \(document.subtaskCount) subtasks."
            )
        } catch {
            presentError(error, operation: "The backup could not be exported")
        }
    }

    func importBackup(from url: URL) {
        isWorking = true
        defer { isWorking = false }

        do {
            let document = try withSecurityScopedAccess(to: url) {
                try Self.decode(contentsOf: url)
            }
            let result = try coordinator.importBackup(document)
            notice = Notice(
                kind: .success,
                title: "Backup Imported",
                message: "Added \(result.listCount) lists, \(result.taskCount) tasks, and \(result.subtaskCount) subtasks. Your existing data was not changed."
            )
        } catch {
            presentError(error, operation: "The backup could not be imported")
        }
    }

    static func encode(_ document: MakeTaskBackupDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    static func decode(contentsOf url: URL) throws -> MakeTaskBackupDocument {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else {
            throw MakeTaskBackupError.invalidJSON
        }
        if let fileSize = values.fileSize,
           fileSize > MakeTaskBackupDocument.maximumFileSize {
            throw MakeTaskBackupError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= MakeTaskBackupDocument.maximumFileSize else {
            throw MakeTaskBackupError.fileTooLarge
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: MakeTaskBackupDocument
        do {
            document = try decoder.decode(MakeTaskBackupDocument.self, from: data)
        } catch {
            throw MakeTaskBackupError.invalidJSON
        }
        try document.validate()
        return document
    }

    private func withSecurityScopedAccess<T>(
        to url: URL,
        operation: () throws -> T
    ) rethrows -> T {
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    private func presentError(_ error: Error, operation: String) {
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        notice = Notice(
            kind: .error,
            title: "Backup Error",
            message: "\(operation). \(detail)"
        )
    }

    private static var defaultFileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "MakeTask Backup \(formatter.string(from: .now)).json"
    }
}
