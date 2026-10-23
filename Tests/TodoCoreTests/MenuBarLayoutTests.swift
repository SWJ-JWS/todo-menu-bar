import Testing
import Foundation
@testable import TodoCore

/// 菜单栏浮窗布局计算测试。
/// 防回归：ScrollView 在 MenuBarExtra .window 自适应尺寸时塌缩为 0，
/// 列表区高度必须由此纯函数显式给出。
struct MenuBarLayoutTests {

    @Test func empty_showsEmptyStateHeight() {
        let h = MenuBarLayout.listHeight(
            pendingCount: 0, completedCount: 0, completedExpanded: true)
        #expect(h == MenuBarLayout.emptyStateHeight)
        #expect(h > 0)  // 核心防回归：任何情况下高度不得为 0
    }

    @Test func pendingOnly_scalesWithRows() {
        let h = MenuBarLayout.listHeight(
            pendingCount: 3, completedCount: 0, completedExpanded: true)
        #expect(h == 3 * MenuBarLayout.rowHeight)
    }

    @Test func completedCollapsed_addsHeaderOnly() {
        let h = MenuBarLayout.listHeight(
            pendingCount: 2, completedCount: 5, completedExpanded: false)
        #expect(h == 2 * MenuBarLayout.rowHeight
                + MenuBarLayout.dividerHeight
                + MenuBarLayout.completedHeaderHeight)
    }

    @Test func completedExpanded_addsRowsAndClearButton() {
        let h = MenuBarLayout.listHeight(
            pendingCount: 2, completedCount: 3, completedExpanded: true)
        #expect(h == 2 * MenuBarLayout.rowHeight
                + MenuBarLayout.dividerHeight
                + MenuBarLayout.completedHeaderHeight
                + 3 * MenuBarLayout.rowHeight
                + MenuBarLayout.clearButtonHeight)
    }

    @Test func manyItems_cappedAtMax() {
        let h = MenuBarLayout.listHeight(
            pendingCount: 100, completedCount: 100, completedExpanded: true)
        #expect(h == MenuBarLayout.maxListHeight)
    }

    @Test func anyInput_heightIsPositive() {
        // 穷举小范围输入，高度永不为 0（塌缩回归的穷举验证）
        for p in 0...5 {
            for c in 0...5 {
                for expanded in [true, false] {
                    #expect(MenuBarLayout.listHeight(
                        pendingCount: p, completedCount: c,
                        completedExpanded: expanded) > 0)
                }
            }
        }
    }
}
