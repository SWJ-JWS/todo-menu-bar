import Foundation

/// 单个待办事项。字段与产品设计文档 §8 定稿逐一对应。
///
/// 注：定稿要求 SwiftData `@Model`，但当前开发机只有 Command Line Tools
/// （无完整 Xcode，缺 SwiftDataMacros 宏插件），`@Model` 无法编译。
/// MVP 先以 Codable 值类型 + JSON 文件持久化落地，字段语义不变；
/// 装回 Xcode 后迁移到 SwiftData 时，字段名/语义一一对应，转换是机械映射。
public struct TodoItem: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var text: String = ""
    public var done: Bool = false
    public var createdAt: Date = .now
    public var completedAt: Date? = nil
    public var order: Int = 0   // 预留：P2 手动排序用，MVP 不参与排序

    public init(text: String, order: Int = 0) {
        self.text = text
        self.order = order
    }
}
