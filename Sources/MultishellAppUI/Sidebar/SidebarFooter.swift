import MultishellCore
import SwiftUI

/// What the workspace holds, under a hairline at the foot of the tree.
struct SidebarFooter: View {
  let worktreeCount: Int
  let terminalCount: Int
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack {
      Text(
        t(
          "sidebar.counts", t("count.worktrees", worktreeCount),
          t("count.terminals", terminalCount))
      )
      .font(.system(size: metrics.caption))
      .foregroundStyle(theme.textTertiary)
      Spacer()
    }
    .padding(.horizontal, 14)
    .frame(height: 30)
    .overlay(alignment: .top) { theme.hairline.frame(height: 0.5) }
  }
}
