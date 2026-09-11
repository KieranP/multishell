import MultishellAppCore
import MultishellCore
import SwiftUI

struct WorktreeRow: View {
  let worktree: Worktree
  /// The name the user gave this worktree, or `nil` for none. Shown in
  /// place of the branch, which drops to a second line under it.
  let customName: String?
  /// The row is showing its name field; the model decides, so the menu that
  /// starts the rename does not have to be the sidebar's.
  let isRenaming: Bool
  let terminalCount: Int
  let state: SessionState?
  /// A create or remove running here, or failed and not yet dismissed.
  let operation: WorktreeOperation?
  let isSelected: Bool
  /// A tab is being dragged over this row and would land here on release.
  let isDropTarget: Bool
  let status: WorktreeStatus?
  /// Whether the branch has already landed on the project's default branch,
  /// which is what says the worktree can go.
  let mergeState: WorktreeMergeState
  let theme: Theme
  let metrics: UIMetrics
  let beginRename: () -> Void
  let commit: (String) -> Void
  let cancel: () -> Void

  private var kind: String { AccessibilityText.kind(of: worktree) }

  private var height: Double {
    metrics.worktreeRowHeight(isNamed: customName != nil, isRenaming: isRenaming)
  }

  var body: some View {
    HStack(spacing: 7) {
      // Always a dot, grey when nothing is running, and keeping its colour
      // when selected, which is why selection is an outline.
      Circle()
        .fill(theme.color(for: state ?? .idle))
        .frame(width: 7, height: 7)
        .frame(width: metrics.icon + 2)
        .help(t("sidebar.kind-and-state", kind, (state ?? .idle).displayName))

      if isRenaming {
        nameField
      } else {
        names
      }

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
          .help(t("sidebar.locked"))
      }
      // Never beside the changes dot or an unpushed count: work that is only
      // here hides the badge. See `WorktreeMergeState.showsBadge`.
      if mergeState.showsBadge(with: status) {
        Image(systemName: "arrow.triangle.merge")
          .font(.system(size: metrics.badge))
          .foregroundStyle(theme.ansiRGB[2].color)
          .help(mergeState.help)
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
          .help(t("count.terminals", terminalCount))
      }
    }
    .padding(.leading, metrics.indent)
    .padding(.trailing, 8)
    .frame(height: height)
    // Selected is a blue outline, not a fill: a filled row tinted the state
    // dot and hid its colour. A faint wash keeps it legible without that.
    .background(
      isSelected || isDropTarget ? Color.accentColor.opacity(0.12) : .clear,
      in: RoundedRectangle(cornerRadius: 6)
    )
    // A dashed border for a hovering tab, the solid one meaning selected and
    // a row being able to be both at once.
    .overlay {
      if isDropTarget {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
      } else if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .strokeBorder(Color.accentColor, lineWidth: 1.5)
      }
    }
    .contentShape(.rect)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      AccessibilityText.worktree(
        worktree, customName: customName, state: state, status: status, operation: operation,
        terminalCount: terminalCount, isSelected: isSelected, mergeState: mergeState)
    )
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(named: t("action.rename-spoken"), beginRename)
  }

  /// The user's name over the branch, or the branch alone. The branch never
  /// disappears, being what every git command here acts on.
  @ViewBuilder
  private var names: some View {
    if let customName {
      VStack(alignment: .leading, spacing: 0) {
        Text(customName)
          .font(.system(size: metrics.secondary, weight: .medium))
          .foregroundStyle(theme.textPrimary.opacity(isSelected ? 1 : 0.85))
          .lineLimit(1)
          .truncationMode(.tail)
        Text(worktree.name)
          .font(.system(size: metrics.badge, design: .monospaced))
          .foregroundStyle(theme.textTertiary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
      .help(worktree.name)
    } else {
      Text(worktree.name)
        .font(.system(size: metrics.mono, design: .monospaced))
        .foregroundStyle(theme.textPrimary.opacity(isSelected ? 1 : 0.8))
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }

  /// An empty name clears the custom one; `InlineNameField` has the keyboard
  /// contract. The branch stays under the field, naming the worktree.
  private var nameField: some View {
    VStack(alignment: .leading, spacing: 0) {
      InlineNameField(
        initial: customName ?? "",
        prompt: t("sidebar.name-prompt"),
        font: .system(size: metrics.secondary, weight: .medium),
        color: theme.textPrimary,
        commit: commit,
        cancel: cancel)
      Text(worktree.name)
        .font(.system(size: metrics.badge, design: .monospaced))
        .foregroundStyle(theme.textTertiary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
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
