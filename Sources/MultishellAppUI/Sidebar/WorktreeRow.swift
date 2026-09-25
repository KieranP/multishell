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
  let commitRename: (String) -> Void
  let cancelRename: () -> Void

  private var kind: String { AccessibilityText.kind(of: worktree) }

  /// The selected worktree lists its panes under itself, so a count on its
  /// row would say the same thing twice.
  private var shownTerminalCount: Int { isSelected ? 0 : terminalCount }

  private var height: Double {
    metrics.worktreeRowHeight(isNamed: customName != nil, isRenaming: isRenaming)
  }

  var body: some View {
    HStack(spacing: 7) {
      // Always a dot, grey when nothing is running, and keeping its colour
      // when selected, which is why selection is an outline.
      StateDot(state: state ?? .idle, theme: theme)
        .frame(width: metrics.icon + 2)
        .help(t("sidebar.kind-and-state", kind, (state ?? .idle).displayName))

      if isRenaming {
        nameField
      } else {
        names
      }

      Spacer(minLength: 4)

      WorktreeRowBadges(
        operation: operation,
        isLocked: worktree.isLocked,
        mergeState: mergeState,
        status: status,
        terminalCount: shownTerminalCount,
        theme: theme,
        metrics: metrics)
    }
    .padding(.leading, metrics.indent)
    .padding(.trailing, 8)
    .frame(height: height)
    .rowSelection(isSelected: isSelected, isDropTarget: isDropTarget)
    .contentShape(.rect)
    // `.contain` while renaming, or the field the Rename action opened would
    // sit inside an ignored subtree where VoiceOver cannot reach it.
    .accessibilityElement(children: isRenaming ? .contain : .ignore)
    .accessibilityLabel(
      AccessibilityText.worktree(
        worktree, customName: customName, state: state, status: status, operation: operation,
        terminalCount: shownTerminalCount, isSelected: isSelected, mergeState: mergeState)
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
        branchLine
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
        commit: commitRename,
        cancel: cancelRename)
      branchLine
    }
  }

  /// The branch under a custom name or a name field, in the smaller of the
  /// two sizes: what the row is called is above it.
  private var branchLine: some View {
    Text(worktree.name)
      .font(.system(size: metrics.badge, design: .monospaced))
      .foregroundStyle(theme.textTertiary)
      .lineLimit(1)
      .truncationMode(.middle)
  }
}

/// Everything but the closures, which are rebuilt on every sidebar render and
/// capture nothing the rest does not already say; see `SidebarView`.
extension WorktreeRow: @MainActor Equatable {
  static func == (a: WorktreeRow, b: WorktreeRow) -> Bool {
    a.worktree == b.worktree && a.customName == b.customName && a.isRenaming == b.isRenaming
      && a.terminalCount == b.terminalCount && a.state == b.state && a.operation == b.operation
      && a.isSelected == b.isSelected && a.isDropTarget == b.isDropTarget
      && a.status == b.status && a.mergeState == b.mergeState && a.theme == b.theme
      && a.metrics == b.metrics
  }
}
