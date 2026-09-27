import Foundation

struct WidgetTaskSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int
    let dueDate: Date?
}

struct WidgetListSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let color: String
    let tasks: [WidgetTaskSnapshot]

    var remainingCount: Int { tasks.filter { !$0.isCompleted }.count }

    func visibleTasks(showCompleted: Bool) -> [WidgetTaskSnapshot] {
        tasks.filter { !$0.isCompleted } + (showCompleted ? tasks.filter(\.isCompleted) : [])
    }
}

struct WidgetSnapshot: Codable, Equatable, Sendable {
    var version = 1
    let lists: [WidgetListSnapshot]

    func list(id: UUID?) -> WidgetListSnapshot? {
        // A deleted configured list must not silently switch to another list.
        guard let id else { return lists.first }
        return lists.first { $0.id == id }
    }
}

enum WidgetDataError: LocalizedError {
    case unavailable, unsupportedVersion, missingTask, appRequired

    var errorDescription: String? {
        switch self {
        case .unavailable: "Widget sharing is unavailable. Build both targets with the same Apple Developer team and App Group."
        case .unsupportedVersion: "Open the latest version of MakeTask to refresh this widget."
        case .missingTask: "This task or list no longer exists. Open MakeTask to refresh the widget."
        case .appRequired: "Open MakeTask once, then try this widget action again."
        }
    }
}

/// The widget reads a small, atomic projection. Only the app writes the real task database.
struct WidgetSnapshotStore {
    let url: URL

    static func shared() throws -> Self {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "MakeTaskWidgetAppGroup") as? String,
              let team = group.split(separator: ".", omittingEmptySubsequences: false).first,
              team.count == 10,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw WidgetDataError.unavailable }
        return Self(url: container.appendingPathComponent("widget-snapshot.json"))
    }

    func read() throws -> WidgetSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.version == 1 else { throw WidgetDataError.unsupportedVersion }
        return snapshot
    }

    @discardableResult
    func write(_ snapshot: WidgetSnapshot) throws -> Bool {
        if let previous = try? read(), previous == snapshot { return false }
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return true
    }
}

enum WidgetRoute: Equatable {
    case home
    case list(UUID)
    case task(UUID)
    case add(UUID?)

    static var scheme: String {
        Bundle.main.object(forInfoDictionaryKey: "MakeTaskURLScheme") as? String ?? "maketask"
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .home: components.host = "open"
        case .list(let id): components.host = "list"; components.path = "/\(id.uuidString)"
        case .task(let id): components.host = "task"; components.path = "/\(id.uuidString)"
        case .add(let id): components.host = "add"; components.path = id.map { "/\($0.uuidString)" } ?? ""
        }
        return components.url!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme, url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        let parts = url.path.split(separator: "/")
        switch (url.host, parts.count) {
        case ("open", 0): self = .home
        case ("add", 0): self = .add(nil)
        case ("list", 1), ("task", 1), ("add", 1):
            guard let id = UUID(uuidString: String(parts[0])) else { return nil }
            if url.host == "list" { self = .list(id) }
            else if url.host == "task" { self = .task(id) }
            else { self = .add(id) }
        default: return nil
        }
    }
}
