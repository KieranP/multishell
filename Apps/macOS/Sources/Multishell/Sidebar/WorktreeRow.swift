import MultishellCore
import SwiftUI

struct WorktreeRow: View {
  let worktree: Worktree
  let terminalCount: Int
  let unseenActivity: Bool
  let isSelected: Bool
  let status: WorktreeStatus?
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(spacing: 7) {
      Image(
        systemName: worktree.isDetached
          ? "point.topleft.down.to.point.bottomright.curvepath" : "arrow.trianglehead.branch"
      )
      .font(.system(size: metrics.icon))
      .foregroundStyle(isSelected ? .white.opacity(0.9) : theme.textSecondary)
      .help(
        worktree.isDetached
          ? "Detached at \(worktree.head.prefix(7))"
          : worktree.isPrimary ? "Main worktree" : "Linked worktree")

      Text(worktree.name)
        .font(.system(size: metrics.mono, design: .monospaced))
        .foregroundStyle(isSelected ? .white : theme.textPrimary.opacity(0.8))
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer(minLength: 4)

      if unseenActivity {
        Circle().fill(isSelected ? .white : Color.accentColor).frame(width: 6, height: 6)
          .help("Activity in a background terminal")
      }
      if worktree.isLocked {
        Image(systemName: "lock.fill")
          .font(.system(size: metrics.badge - 1))
          .foregroundStyle(isSelected ? .white.opacity(0.7) : theme.textTertiary)
          .help("Locked worktree")
      }
      if terminalCount > 0 {
        Text("\(terminalCount)")
          .font(.system(size: metrics.badge, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(isSelected ? .white : theme.textSecondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(isSelected ? .white.opacity(0.24) : theme.rowHover, in: Capsule())
          .help("\(terminalCount) terminal\(terminalCount == 1 ? "" : "s")")
      }
      if let status, !status.isClean {
        changes(status)
      }
    }
    .padding(.leading, metrics.indent)
    .padding(.trailing, 8)
    .frame(height: metrics.rowHeight)
    .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
    .contentShape(.rect)
  }

  /// A dot in the theme's yellow while files are changed, with the count;
  /// arrows for commits not yet pushed or pulled. Hover for the breakdown.
  private func changes(_ status: WorktreeStatus) -> some View {
    HStack(spacing: 3) {
      if status.isDirty {
        Circle()
          .fill(isSelected ? .white : theme.ansiRGB[3].color)
          .frame(width: 6, height: 6)
        Text("\(status.changedFiles)")
      }
      if status.ahead > 0 { Text("↑\(status.ahead)") }
      if status.behind > 0 { Text("↓\(status.behind)") }
    }
    .font(.system(size: metrics.badge, weight: .medium))
    .monospacedDigit()
    .foregroundStyle(isSelected ? .white.opacity(0.9) : theme.textSecondary)
    .help(status.summary)
  }
}
