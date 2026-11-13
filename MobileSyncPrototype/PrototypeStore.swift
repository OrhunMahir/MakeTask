import CloudKit
import Foundation

struct PrototypeList: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var color: NoteColor
    var order: Int
    var createdAt: Date? = .now
}

struct PrototypeSubtask: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var completedAt: Date?
    var createdAt: Date? = .now
}

struct PrototypeTask: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var listID: UUID
    var title: String
    var order: Int
    var notes = ""
    var dueDate: Date?
    var priority: TaskPriority = .none
    var isInProgress = false
    var completedAt: Date?
    var subtasks: [PrototypeSubtask] = []
    var createdAt: Date? = .now

    var isCompleted: Bool { completedAt != nil }

    var statusSymbol: String {
        if isCompleted { return "checkmark.circle.fill" }
        return isInProgress ? "circle.lefthalf.filled" : "circle"
    }

    func matches(_ query: String) -> Bool {
        query.isEmpty || title.localizedCaseInsensitiveContains(query)
            || notes.localizedCaseInsensitiveContains(query)
            || subtasks.contains { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

enum PrototypeContent: Codable, Equatable, Sendable {
    case list(PrototypeList)
    case task(PrototypeTask)
    case deleted
}

struct PrototypeRecord: Codable, Sendable {
    let id: UUID
    var content: PrototypeContent
    var revision = UUID()
    var needsUpload = true
    var serverFields: Data?
    var restoresDeletion: UUID?
}

struct PrototypeStore: Codable {
    var records: [UUID: PrototypeRecord] = [:]
    var account: String?
    var engineState: CKSyncEngine.State.Serialization?

    static func load(from url: URL) throws -> Self {
        do {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        } catch CocoaError.fileReadNoSuchFile {
            return Self()
        }
    }

    func save(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}
