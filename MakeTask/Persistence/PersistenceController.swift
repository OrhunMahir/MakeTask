import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            TodoList.self,
            TodoTask.self,
            TodoSubtask.self
        ])
        let configuration = ModelConfiguration(
            "MakeTask",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
