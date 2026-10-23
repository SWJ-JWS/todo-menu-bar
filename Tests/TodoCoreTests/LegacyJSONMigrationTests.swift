import Testing
import Foundation
import SwiftData
@testable import TodoCore

/// 旧 JSON 数据一次性迁移测试。
@MainActor
struct LegacyJSONMigrationTests {

    private func makeContainer() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: TodoItem.self, configurations: config)
    }

    private func writeLegacyJSON(dir: URL) -> URL {
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = """
        [
          {"id":"11111111-1111-1111-1111-111111111111","text":"旧事项一","done":false,
           "createdAt":"2026-10-21T12:00:00Z","completedAt":null,"order":0},
          {"id":"22222222-2222-2222-2222-222222222222","text":"旧事项二","done":true,
           "createdAt":"2026-10-21T12:01:00Z","completedAt":"2026-10-21T13:00:00Z","order":0}
        ]
        """
        let file = dir.appendingPathComponent("todos.json")
        try! json.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    @Test func import_emptyDatabase_importsAll() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = writeLegacyJSON(dir: dir)

        let container = makeContainer()
        let count = LegacyJSONMigration.importIfNeeded(
            context: container.mainContext, fileURL: file)

        #expect(count == 2)
        let items = try container.mainContext.fetch(FetchDescriptor<TodoItem>())
        #expect(items.count == 2)
        let done = items.first { $0.done }
        #expect(done?.text == "旧事项二")
        #expect(done?.completedAt != nil)
        // 旧文件已归档，防止重复导入
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(FileManager.default.fileExists(
            atPath: file.appendingPathExtension("imported").path))
    }

    @Test func import_nonEmptyDatabase_skips() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = writeLegacyJSON(dir: dir)

        let container = makeContainer()
        TodoStore(context: container.mainContext).add(text: "已有数据")
        let count = LegacyJSONMigration.importIfNeeded(
            context: container.mainContext, fileURL: file)

        #expect(count == 0)
        let items = try container.mainContext.fetch(FetchDescriptor<TodoItem>())
        #expect(items.count == 1)
        // 未导入，旧文件保持原样
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func import_missingFile_noOp() {
        let container = makeContainer()
        let count = LegacyJSONMigration.importIfNeeded(
            context: container.mainContext,
            fileURL: URL(fileURLWithPath: "/tmp/不存在的文件.json"))
        #expect(count == 0)
    }
}
