import Foundation

/// 持久化后端协议。默认实现是 JSON 文件；测试用内存实现。
/// 迁回 SwiftData 时只动这一层。
public protocol TodoStorage: Sendable {
    func load() -> [TodoItem]
    func persist(_ items: [TodoItem])
}

/// JSON 文件持久化：~/Library/Application Support/TodoApp/todos.json
public struct JSONTodoStorage: TodoStorage {

    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TodoApp", isDirectory: true)
            self.fileURL = dir.appendingPathComponent("todos.json")
        }
    }

    public func load() -> [TodoItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([TodoItem].self, from: data)) ?? []
    }

    public func persist(_ items: [TodoItem]) {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[TodoStorage] 持久化失败: \(error)")
        }
    }
}

/// 内存存储：测试专用，不碰磁盘。
public final class InMemoryTodoStorage: TodoStorage, @unchecked Sendable {
    private var items: [TodoItem] = []
    public private(set) var persistCallCount = 0

    public init() {}

    public func load() -> [TodoItem] { items }

    public func persist(_ items: [TodoItem]) {
        self.items = items
        persistCallCount += 1
    }
}
