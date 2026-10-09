import MultishellCore
import MultishellGitKit

extension AccessibilityText {
  /// A project row: the name, whether it is open, and the dot it carries
  /// while collapsed.
  public static func project(
    name: String,
    isExpanded: Bool,
    isMissing: Bool,
    state: SessionState?,
    worktreeCount: Int,
    isFetching: Bool = false,
  ) -> String {
    var parts = [
      t("spoken.project", name),
      isExpanded ? t("spoken.expanded") : t("spoken.collapsed"),
    ]
    parts.append(t("count.worktrees", worktreeCount))
    if isMissing { parts.append(t("spoken.not-reachable")) }
    if isFetching { parts.append(t("spoken.fetching")) }
    if let state { parts.append(state.displayName) }
    return parts.joined(separator: ", ")
  }

  /// A worktree row: what its glyphs mean, in drawing order. A renamed row
  /// reads its name first and its branch after, the two lines it shows.
  public static func worktree(
    _ worktree: Worktree,
    state: SessionState?,
    status: WorktreeStatus?,
    operation: WorktreeOperation?,
    terminalCount: Int,
    isSelected: Bool,
    customName: String? = nil,
    mergeState: WorktreeMergeState = .unknown,
  ) -> String {
    var parts = [
      t("spoken.named", customName ?? worktree.name, worktree.kindText(inSentence: true))
    ]
    if customName != nil { parts.append(t("spoken.branch", worktree.name)) }
    if isSelected { parts.append(t("spoken.selected")) }
    parts.append(state.shownState.displayName)
    if let operation {
      parts.append(
        operation.isRunning ? operation.title : t("spoken.operation-failed", operation.title)
      )
    }
    if worktree.isLocked { parts.append(t("spoken.locked")) }
    if mergeState.showsBadge(with: status) { parts.append(mergeState.summary) }
    if let status = WorktreeStatus.badged(status) { parts.append(status.summary) }
    if terminalCount > 0 { parts.append(t("count.terminals", terminalCount)) }
    return parts.joined(separator: ", ")
  }

  /// A pane's row in the sidebar: its title, which pane of a split it is,
  /// whether it is the one with the keyboard, its state and its workers.
  public static func pane(_ pane: SidebarPane) -> String {
    // One pane of a split is not a tab, so only a whole tab is read as one.
    var parts = [pane.position == nil ? t("spoken.tab", pane.title) : pane.title]
    parts.append(contentsOf: spokenAgent(pane.agentName, title: pane.title))
    if let position = pane.position { parts.append(panePosition(position)) }
    if pane.isFocused { parts.append(t("spoken.selected")) }
    if let state = pane.state { parts.append(state.displayName) }
    if !pane.workers.isEmpty { parts.append(pane.workers.countText) }
    return parts.joined(separator: ", ")
  }
}
