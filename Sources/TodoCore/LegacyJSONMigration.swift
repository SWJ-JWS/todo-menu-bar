import Foundation
import SwiftData

/// 一次性迁移：MVP 第一版在无 Xcode 环境下曾用 JSON 文件持久化
/// （~/Library/Application Support/TodoApp/todos.json）。
/// 迁回 SwiftData 后，启动时若数据库为空且旧 JSON 存在，则导入并归档旧文件。
/// 幂等：只在数据库为空时执行；导入成功后旧文件改名归档，不会重复导入。
@MainActor
public enum LegacyJSONMigration {

    /// 旧 JSON 格式（与 v0.1.0 的 Codable TodoItem 字段一致）
    private struct LegacyItem: Codable {
        var id: UUID
        var text: String
        var done: Bool
        var createdAt: Date
        var completedAt: Date?
        var order: Int
    }

    /// 返回导入条数；无需导入时返回 0。
    @discardableResult
    public static func importIfNeeded(context: ModelContext, fileURL: URL? = nil) -> Int {
        let existing = (try? context.fetchCount(FetchDescriptor<TodoItem>())) ?? 0
        guard existing == 0 else { return 0 }

        let url = fileURL ?? defaultFileURL
        guard let data = try? Data(contentsOf: url) else { return 0 }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let legacy = try? decoder.decode([LegacyItem].self, from: data),
              !legacy.isEmpty else { return 0 }

        for old in legacy {
            let item = TodoItem(text: old.text, order: old.order)
            item.id = old.id
            item.done = old.done
            item.createdAt = old.createdAt
            item.completedAt = old.completedAt
            context.insert(item)
        }
        try? context.save()
        // 归档旧文件，防止下次重复导入
        try? FileManager.default.moveItem(
            at: url,
            to: url.appendingPathExtension("imported")
        )
        NSLog("[LegacyJSONMigration] 已从 JSON 导入 \(legacy.count) 条旧数据")
        return legacy.count
    }

    private static var defaultFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TodoApp/todos.json")
    }
}
