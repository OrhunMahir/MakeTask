import CloudKit
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class PrototypeSync: CKSyncEngineDelegate {
    static let containerID = "iCloud.dev.orhun.MakeTask.SyncPrototype"
    private static let zoneID = CKRecordZone.ID(zoneName: "MakeTaskPrototypeV2")
    private nonisolated static let recordType = "PrototypeItem"

    private let storeURL: URL
    private var store = PrototypeStore()
    private var engine: CKSyncEngine?
    private var storeReadable = true
    private var undoStack: [[Edit]] = []
    private var redoStack: [[Edit]] = []
    private(set) var isWorking = false
    private(set) var message: String?

    private struct Edit {
        let id: UUID
        let before: PrototypeContent
        let after: PrototypeContent
    }

    var isConnected: Bool { engine != nil }
    var lists: [PrototypeList] {
        store.records.values.compactMap { record -> PrototypeList? in
            guard case .list(let list) = record.content else { return nil }
            return list
        }
        .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
    }
    var pendingCount: Int { store.records.values.filter(\.needsUpload).count }
    var canUndo: Bool { undoStack.last?.allSatisfy { content(at: $0.id) == $0.after } == true }
    var canRedo: Bool { redoStack.last?.allSatisfy { content(at: $0.id) == $0.before } == true }

    func list(id: UUID) -> PrototypeList? {
        guard case .list(let list) = store.records[id]?.content else { return nil }
        return list
    }

    func tasks(in listID: UUID) -> [PrototypeTask] {
        store.records.values.compactMap { record -> PrototypeTask? in
            guard case .task(let task) = record.content, task.listID == listID else { return nil }
            return task
        }
        .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
    }

    func task(id: UUID) -> PrototypeTask? {
        guard case .task(let task) = store.records[id]?.content else { return nil }
        return task
    }

    init(storeURL: URL = URL.applicationSupportDirectory
        .appending(path: "MakeTaskSyncPrototype/store-v2.json")) {
        self.storeURL = storeURL
        do {
            store = try PrototypeStore.load(from: storeURL)
        } catch {
            storeReadable = false
            message = error.localizedDescription
        }
    }

    func saveList(_ list: PrototypeList) {
        var list = list
        if let existing = store.records[list.id] {
            guard case .list(let current) = existing.content else { return }
            list.order = current.order
        } else {
            list.order = (lists.last?.order ?? -1) + 1
        }
        saveChanges([(list.id, .list(list))])
    }

    func newList() -> PrototypeList {
        PrototypeList(id: UUID(), title: "", color: .yellow, order: 0)
    }

    func deleteList(id: UUID) {
        let removed: [(UUID, PrototypeContent)] = tasks(in: id).map { ($0.id, .deleted) }
        saveChanges([(id, .deleted)] + removed)
    }

    func addTask(title: String, listID: UUID) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, list(id: listID) != nil else { return }
        let order = (tasks(in: listID).last?.order ?? -1) + 1
        let task = PrototypeTask(id: UUID(), listID: listID, title: title, order: order)
        saveChanges([(task.id, .task(task))])
    }

    func saveTask(_ task: PrototypeTask) {
        guard let original = self.task(id: task.id), list(id: task.listID) != nil else { return }
        var task = task
        if original.listID != task.listID {
            task.order = (tasks(in: task.listID).last?.order ?? -1) + 1
        } else {
            task.order = original.order
        }
        saveChanges([(task.id, .task(task))])
    }

    func toggleTask(id: UUID) {
        guard var task = task(id: id) else { return }
        task.completedAt = task.isCompleted ? nil : .now
        saveTask(task)
    }

    func deleteTasks(_ ids: [UUID]) {
        saveChanges(ids.map { ($0, .deleted) })
    }

    func reorderLists(from source: IndexSet, to destination: Int) {
        var reordered = lists
        guard source.allSatisfy(reordered.indices.contains), (0...reordered.count).contains(destination) else { return }
        reordered.move(fromOffsets: source, toOffset: destination)
        saveChanges(reordered.enumerated().compactMap { order, list in
            guard order != list.order else { return nil }
            var updated = list
            updated.order = order
            return (updated.id, .list(updated))
        })
    }

    func reorderTasks(in listID: UUID, from source: IndexSet, to destination: Int) {
        let tasks = tasks(in: listID)
        var reordered = tasks.filter { !$0.isCompleted }
        guard source.allSatisfy(reordered.indices.contains), (0...reordered.count).contains(destination) else { return }
        reordered.move(fromOffsets: source, toOffset: destination)
        var activeTasks = reordered.makeIterator()
        let merged = tasks.map { task in
            task.isCompleted ? task : (activeTasks.next() ?? task)
        }
        saveChanges(merged.enumerated().compactMap { order, task in
            guard task.order != order else { return nil }
            var updated = task
            updated.order = order
            return (updated.id, .task(updated))
        })
    }

    func undo() {
        guard canUndo, let edits = undoStack.last,
              applyChanges(edits.map { ($0.id, $0.before) }) else { return }
        undoStack.removeLast()
        redoStack.append(edits)
    }

    func redo() {
        guard canRedo, let edits = redoStack.last,
              applyChanges(edits.map { ($0.id, $0.after) }) else { return }
        redoStack.removeLast()
        undoStack.append(edits)
    }

    private func content(at id: UUID) -> PrototypeContent {
        store.records[id]?.content ?? .deleted
    }

    @discardableResult
    func saveChanges(_ changes: [(UUID, PrototypeContent)]) -> Bool {
        let edits = changes.compactMap { id, after -> Edit? in
            let before = content(at: id)
            guard before != after else { return nil }
            return Edit(id: id, before: before, after: after)
        }
        guard !edits.isEmpty else { return true }
        guard applyChanges(edits.map { ($0.id, $0.after) }) else { return false }
        undoStack.append(edits)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        return true
    }

    private func applyChanges(_ changes: [(UUID, PrototypeContent)]) -> Bool {
        var updated = store
        for (id, content) in changes {
            let previous = store.records[id]
            let restoresDeletion: UUID?
            switch (previous?.content, content) {
            case (_, .deleted): restoresDeletion = nil
            case (.deleted?, _): restoresDeletion = previous?.revision
            default: restoresDeletion = previous?.restoresDeletion
            }
            updated.records[id] = PrototypeRecord(
                id: id, content: content, serverFields: previous?.serverFields,
                restoresDeletion: restoresDeletion
            )
        }
        guard persist(updated) else { return false }
        if let engine { enqueueUploads(in: engine) }
        return true
    }

    private func persist(_ updated: PrototypeStore) -> Bool {
        guard storeReadable else { return false }
        do {
            try updated.save(to: storeURL)
            store = updated
            return true
        } catch {
            engine = nil
            message = error.localizedDescription
            return false
        }
    }

    func syncNow() async {
        guard storeReadable, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        message = nil
        do {
            let container = CKContainer(identifier: Self.containerID)
            let account = try await container.userRecordID().recordName
            guard store.account == nil || store.account == account else {
                engine = nil
                message = "This preview store is linked to another iCloud account."
                return
            }
            if engine == nil {
                var updated = store
                updated.account = account
                guard persist(updated) else { return }
                let configuration = CKSyncEngine.Configuration(
                    database: container.privateCloudDatabase,
                    stateSerialization: store.engineState,
                    delegate: self
                )
                engine = CKSyncEngine(configuration)
            }
            guard let engine else { return }
            enqueueUploads(in: engine)
            try await engine.sendChanges()
            guard self.engine === engine else { return }
            try await engine.fetchChanges()
        } catch {
            message = error.localizedDescription
        }
    }

    func pause() {
        engine = nil
        message = nil
    }

    private func enqueueUploads(in engine: CKSyncEngine) {
        let changes = store.records.values.filter(\.needsUpload).map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(Self.recordID(for: $0.id))
        }
        guard !changes.isEmpty else { return }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard engine === syncEngine else { return nil }
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        let records = store.records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { recordID in
            guard let id = UUID(uuidString: recordID.recordName), let item = records[id], item.needsUpload else {
                syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
                return nil
            }
            return Self.makeRecord(for: item, id: recordID)
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard engine === syncEngine else { return }
        var updated = store
        switch event {
        case .stateUpdate(let event):
            updated.engineState = event.stateSerialization
        case .accountChange(let event):
            if case .signIn(let currentUser) = event.changeType,
               currentUser.recordName == store.account {
                enqueueUploads(in: syncEngine)
                return
            }
            engine = nil
            updated.engineState = nil
            if persist(updated) { message = "The iCloud account changed. Reconnect to continue syncing." }
            return
        case .fetchedRecordZoneChanges(let event):
            for modification in event.modifications {
                Self.apply(modification.record, to: &updated)
            }
            for deletion in event.deletions where deletion.recordID.zoneID == Self.zoneID {
                if let id = UUID(uuidString: deletion.recordID.recordName) {
                    Self.removeServerCopy(id: id, from: &updated)
                }
            }
        case .fetchedDatabaseChanges(let event):
            if event.deletions.contains(where: { $0.zoneID == Self.zoneID }) {
                for id in Array(updated.records.keys) {
                    Self.removeServerCopy(id: id, from: &updated)
                }
            }
        case .sentRecordZoneChanges(let event):
            for record in event.savedRecords {
                Self.apply(record, to: &updated)
            }
            var retries: [CKSyncEngine.PendingRecordZoneChange] = []
            var recreateZone = false
            for failure in event.failedRecordSaves {
                let recordID = failure.record.recordID
                switch failure.error.code {
                case .serverRecordChanged:
                    guard let serverRecord = failure.error.serverRecord else {
                        message = failure.error.localizedDescription
                        continue
                    }
                    Self.apply(serverRecord, to: &updated)
                case .zoneNotFound, .unknownItem:
                    guard let id = UUID(uuidString: recordID.recordName) else { continue }
                    updated.records[id]?.serverFields = nil
                    recreateZone = recreateZone || failure.error.code == .zoneNotFound
                default:
                    message = failure.error.localizedDescription
                    continue
                }
                if let id = UUID(uuidString: recordID.recordName), updated.records[id]?.needsUpload == true {
                    retries.append(.saveRecord(recordID))
                }
            }
            guard persist(updated) else { return }
            if recreateZone {
                syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: Self.zoneID))])
            }
            let editedWhileSending = event.savedRecords.compactMap { record -> CKSyncEngine.PendingRecordZoneChange? in
                guard let id = UUID(uuidString: record.recordID.recordName),
                      updated.records[id]?.needsUpload == true else { return nil }
                return .saveRecord(record.recordID)
            }
            syncEngine.state.add(pendingRecordZoneChanges: retries + editedWhileSending)
            return
        default:
            return
        }
        _ = persist(updated)
    }

    private static func recordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    private nonisolated static func makeRecord(for item: PrototypeRecord, id: CKRecord.ID) -> CKRecord? {
        let record: CKRecord
        if let fields = item.serverFields,
           let decoder = try? NSKeyedUnarchiver(forReadingFrom: fields) {
            decoder.requiresSecureCoding = true
            record = CKRecord(coder: decoder) ?? CKRecord(recordType: recordType, recordID: id)
            decoder.finishDecoding()
        } else {
            record = CKRecord(recordType: recordType, recordID: id)
        }
        guard let payload = try? JSONEncoder().encode(item.content) else { return nil }
        record["payload"] = payload
        record["revision"] = item.revision.uuidString
        return record
    }

    private static func apply(_ record: CKRecord, to store: inout PrototypeStore) {
        guard record.recordID.zoneID == zoneID, record.recordType == recordType,
              let id = UUID(uuidString: record.recordID.recordName),
              let payload = record["payload"] as? Data,
              let content = try? JSONDecoder().decode(PrototypeContent.self, from: payload),
              let revisionString = record["revision"] as? String,
              let revision = UUID(uuidString: revisionString) else { return }
        let encoder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: encoder)
        encoder.finishEncoding()
        if let local = store.records[id], local.needsUpload, local.restoresDeletion == revision {
            store.records[id]?.serverFields = encoder.encodedData
        } else if case .deleted = content {
            store.records[id] = PrototypeRecord(
                id: id, content: .deleted, revision: revision, needsUpload: false,
                serverFields: encoder.encodedData
            )
        } else if let local = store.records[id], local.needsUpload, local.revision != revision {
            store.records[id]?.serverFields = encoder.encodedData
        } else {
            store.records[id] = PrototypeRecord(
                id: id, content: content, revision: revision, needsUpload: false,
                serverFields: encoder.encodedData
            )
        }
    }

    private static func removeServerCopy(id: UUID, from store: inout PrototypeStore) {
        if store.records[id]?.needsUpload == true {
            store.records[id]?.serverFields = nil
        } else {
            store.records[id] = nil
        }
    }
}
