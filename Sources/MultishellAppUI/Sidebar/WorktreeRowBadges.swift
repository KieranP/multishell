import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

/// The glyphs at a worktree row's right end. Several views rather than one,
/// so the row's own spacing sits between them.
struct WorktreeRowBadges: View {
  let operation: WorktreeOperation?
  let isLocked: Bool
  let mergeState: WorktreeMergeState
  let status: WorktreeStatus?
  /// Already zero where the pane rows list them; see `SidebarWorktree`.
  let terminalCount: Int
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    if let operation {
      if operation.isRunning {
        ProgressView()
          .controlSize(.mini)
          .help(operation.title)
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: metrics.badge))
          .foregroundStyle(theme.failureColor)
          .help(operation.title)
          .accessibilityLabel(operation.title)
      }
    }
    if isLocked {
      Image(systemName: "lock.fill")
        .font(.system(size: metrics.small))
        .foregroundStyle(theme.textTertiary)
        .help(t("sidebar.locked"))
        .accessibilityLabel(t("sidebar.locked"))
    }
    // Never beside the line counts or an unpushed count: work that is only
    // here hides the badge. See `WorktreeMergeState.showsBadge`.
    if mergeState.showsBadge(with: status) {
      Image(systemName: "arrow.triangle.merge")
        .font(.system(size: metrics.badge))
        .foregroundStyle(theme.mergedColor)
        .help(mergeState.tooltip)
        .accessibilityLabel(mergeState.tooltip)
    }
    // Git changes sit left of the terminal count, so the count stays at
    // the row's right edge and lines up with rows that have no changes.
    if let status = WorktreeStatus.badged(status) {
      GitStatusBadge(status: status, theme: theme, size: metrics.badge, tint: theme.textSecondary)
    }
    if terminalCount > 0 {
      Text("\(terminalCount)")
        .font(.system(size: metrics.badge, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(theme.faintFill, in: Capsule())
        .help(t("count.terminals", terminalCount))
    }
  }
}
