import MultishellAppCore
import MultishellCore
import SwiftUI

struct WorktreeRow: View {
  let worktree: Worktree
  let terminalCount: Int
  let state: SessionState?
  /// A create or remove running here, or failed and not yet dismissed.
  let operation: WorktreeOperation?
  let isSelected: Bool
  let status: WorktreeStatus?
  let theme: Theme
  let metrics: UIMetrics

  private var kind: String {
    if worktree.isDetached { return "Detached at \(worktree.head.prefix(7))" }
    return worktree.isPrimary ? "Main worktree" : "Linked worktree"
  }

  var body: some View {
    HStack(spacing: 7) {
      // Always a dot, grey when nothing is running: the row's one glance
      // answers "is anything happening here". It keeps its real colour when
      // the row is selected, which is why selection is an outline rather
      // than a fill that would tint the dot.
      Circle()
        .fill(theme.color(for: state ?? .idle))
        .frame(width: 7, height: 7)
        .frame(width: metrics.icon + 2)
        .help("\(kind) · \((state ?? .idle).displayName)")

      Text(worktree.name)
        .font(.system(size: metrics.mono, design: .monospaced))
        .foregroundStyle(theme.textPrimary.opacity(isSelected ? 1 : 0.8))
        .lineLimit(1)
        .truncationMode(.middle)

      Spacer(minLength: 4)

      if let operation {
        if operation.isRunning {
          ProgressView()
            .controlSize(.mini)
            .help(operation.title)
        } else {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: metrics.badge))
            .foregroundStyle(theme.ansiRGB[1].color)
            .help(operation.title)
        }
      }
      if worktree.isLocked {
        Image(systemName: "lock.fill")
          .font(.system(size: metrics.badge - 1))
          .foregroundStyle(theme.textTertiary)
          .help("Locked worktree")
      }
      // Git changes sit left of the terminal count, so the count stays at
      // the row's right edge and lines up with rows that have no changes.
      if let status, !status.isClean {
        changes(status)
      }
      if terminalCount > 0 {
        Text("\(terminalCount)")
          .font(.system(size: metrics.badge, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(theme.textSecondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(theme.rowHover, in: Capsule())
          .help("\(terminalCount) terminal\(terminalCount == 1 ? "" : "s")")
      }
    }
    .padding(.leading, metrics.indent)
    .padding(.trailing, 8)
    .frame(height: metrics.rowHeight)
    // Selected is a blue outline, not a fill: a filled row tinted the state
    // dot and hid its colour. A faint wash keeps it legible without that.
    .background(
      isSelected ? Color.accentColor.opacity(0.12) : .clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    .overlay {
      if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, lineWidth: 1.5)
      }
    }
    .contentShape(.rect)
  }

  /// A dot in the theme's yellow while files are changed, with the count;
  /// arrows for commits not yet pushed or pulled. Hover for the breakdown.
  private func changes(_ status: WorktreeStatus) -> some View {
    HStack(spacing: 3) {
      if status.isDirty {
        Circle()
          .fill(theme.ansiRGB[3].color)
          .frame(width: 6, height: 6)
        Text("\(status.changedFiles)")
      }
      if status.ahead > 0 { Text("↑\(status.ahead)") }
      if status.behind > 0 { Text("↓\(status.behind)") }
    }
    .font(.system(size: metrics.badge, weight: .medium))
    .monospacedDigit()
    .foregroundStyle(theme.textSecondary)
    .help(status.summary)
  }
}
