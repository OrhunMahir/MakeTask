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
            isStoredInMemoryOnly: inMemory,
            // Adding App Groups must not move the existing 1.0.1 store.
            groupContainer: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
