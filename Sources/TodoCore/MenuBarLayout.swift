import Foundation

/// 菜单栏浮窗布局计算（纯函数，可测）。
///
/// 背景（实测踩坑）：MenuBarExtra .window 样式的浮窗按内容自适应尺寸，
/// ScrollView 在该语境下固有高度塌缩为 0 —— 现象是浮窗只剩输入框、
/// 列表区整个消失。因此列表区高度必须显式计算，不能让 ScrollView 自适应。
public enum MenuBarLayout {

    /// 单行事项行高（勾选按钮 + 文字 + 纵向 padding）
    public static let rowHeight: CGFloat = 33
    /// 空态提示区高度
    public static let emptyStateHeight: CGFloat = 60
    /// 已完成分组头高度
    public static let completedHeaderHeight: CGFloat = 30
    /// 「清除已完成」按钮高度
    public static let clearButtonHeight: CGFloat = 30
    /// 分隔线高度
    public static let dividerHeight: CGFloat = 1
    /// 列表区最大高度，超出部分滚动
    public static let maxListHeight: CGFloat = 380

    /// 列表区高度：按行数计算，封顶 maxListHeight。
    /// - Parameters:
    ///   - pendingCount: 未完成事项数
    ///   - completedCount: 已完成事项数
    ///   - completedExpanded: 已完成区是否展开
    public static func listHeight(
        pendingCount: Int,
        completedCount: Int,
        completedExpanded: Bool
    ) -> CGFloat {
        var height: CGFloat = pendingCount == 0
            ? emptyStateHeight
            : CGFloat(pendingCount) * rowHeight

        if completedCount > 0 {
            height += dividerHeight + completedHeaderHeight
            if completedExpanded {
                height += CGFloat(completedCount) * rowHeight + clearButtonHeight
            }
        }
        return min(height, maxListHeight)
    }
}
