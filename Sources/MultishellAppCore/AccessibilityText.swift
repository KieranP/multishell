import MultishellCore

/// What a screen reader says for the rows and tabs drawn by hand, neither
/// being a system list that would describe itself.
public enum AccessibilityText {
  /// A project row: the name, whether it is open, and the dot it carries
  /// while collapsed.
  public static func project(
    name: String, isExpanded: Bool, isMissing: Bool, state: SessionState?, worktreeCount: Int,
    isFetching: Bool = false
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
    _ worktree: Worktree, customName: String? = nil, state: SessionState?,
    status: WorktreeStatus?, operation: WorktreeOperation?, terminalCount: Int, isSelected: Bool,
    mergeState: WorktreeMergeState = .unknown
  ) -> String {
    var parts = [
      t("spoken.named", customName ?? worktree.name, kind(of: worktree, inSentence: true))
    ]
    if customName != nil { parts.append(t("spoken.branch", worktree.name)) }
    if isSelected { parts.append(t("spoken.selected")) }
    parts.append((state ?? .idle).displayName)
    if let operation {
      parts.append(
        operation.isRunning ? operation.title : t("spoken.operation-failed", operation.title))
    }
    if worktree.isLocked { parts.append(t("spoken.locked")) }
    if mergeState.showsBadge(with: status) { parts.append(mergeState.summary) }
    if let status, !status.isClean { parts.append(status.summary) }
    if terminalCount > 0 { parts.append(t("count.terminals", terminalCount)) }
    return parts.joined(separator: ", ")
  }

  /// What kind of worktree, also the tooltip on the row's dot. `inSentence`
  /// is the same fact mid-sentence; see docs/design/translation.md.
  public static func kind(of worktree: Worktree, inSentence: Bool = false) -> String {
    if worktree.isBare {
      return inSentence ? t("kind.bare-in-sentence") : t("kind.bare")
    }
    if worktree.isDetached {
      let head = String(worktree.head.prefix(7))
      return inSentence
        ? t("kind.detached-in-sentence", head) : t("kind.detached", head)
    }
    if worktree.isPrimary {
      return inSentence ? t("kind.main-in-sentence") : t("kind.main")
    }
    return inSentence ? t("kind.linked-in-sentence") : t("kind.linked")
  }

  /// A tab in the strip: its title, whether it is the one shown, its state
  /// and whether it is split.
  public static func tab(
    title: String, isActive: Bool, isSplit: Bool, state: SessionState?
  )
    -> String
  {
    var parts = [t("spoken.tab", title)]
    if isActive { parts.append(t("spoken.selected")) }
    if isSplit { parts.append(t("spoken.split")) }
    if let state { parts.append(state.displayName) }
    return parts.joined(separator: ", ")
  }

  /// One column of tabs, said before its tabs are. Empty for a worktree with
  /// one column, "group 1 of 1" before every tab being noise.
  public static func tabGroup(position: Int, of count: Int, isFocused: Bool) -> String {
    guard count > 1 else { return "" }
    var text = t("spoken.tab-group", position, count)
    if isFocused { text += ", " + t("spoken.focused") }
    return text
  }

  /// The band down the edge of a column's terminal area, which a dragged
  /// tab lands on to get a column of its own.
  public static func newTabGroupBand(_ placement: TerminalTab.Placement) -> String {
    placement == .before
      ? t("spoken.new-tab-group-left") : t("spoken.new-tab-group-right")
  }
}
