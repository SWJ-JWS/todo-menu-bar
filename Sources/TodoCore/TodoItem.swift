import SwiftData
import Foundation

/// 单个待办事项。产品设计文档 §8 定稿模型。
/// 字段全部带默认值（`completedAt` 可选）——CloudKit 兼容写法，
/// P2 开同步时模型零改动、免迁移。
/// （与定稿代码的唯一差异：补了 public，因为本工程按库/应用双目标拆分，跨目标访问需要。）
@Model
public final class TodoItem {
    public var id: UUID = UUID()
    public var text: String = ""
    public var done: Bool = false
    // Xcode 27 的 @Model 宏要求默认值写成全限定形式，`.now` 会被拒；
    // Date() 语义相同（语义差异：无）。
    public var createdAt: Date = Date()
    public var completedAt: Date? = nil
    public var order: Int = 0   // 预留：P2 手动排序用，MVP 不参与排序

    public init(text: String, order: Int = 0) {
        self.text = text
        self.order = order
    }
}
