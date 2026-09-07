import MultishellCore

/// What a screen reader says for the rows and tabs the sidebar and tab strip
/// draw by hand, since neither is a system list that would describe itself.
/// Plain functions of what the row shows, so the wording is tested here.
public enum AccessibilityText {
  /// A project row: the name, whether it is open, and the dot it carries
  /// while collapsed.
  public static func project(
    name: String, isExpanded: Bool, isMissing: Bool, state: SessionState?, worktreeCount: Int,
    isFetching: Bool = false
  ) -> String {
    var parts = ["\(name), project", isExpanded ? "expanded" : "collapsed"]
    parts.append(Wording.count(worktreeCount, "worktree"))
    if isMissing { parts.append("not reachable") }
    if isFetching { parts.append("fetching") }
    if let state { parts.append(state.displayName) }
    return parts.joined(separator: ", ")
  }

  /// A worktree row: everything its glyphs mean, in the order they are
  /// drawn. A renamed row reads its name first and its branch after, the
  /// two lines it shows.
  public static func worktree(
    _ worktree: Worktree, customName: String? = nil, state: SessionState?,
    status: WorktreeStatus?, operation: WorktreeOperation?, terminalCount: Int, isSelected: Bool,
    mergeState: WorktreeMergeState = .unknown
  ) -> String {
    var parts = ["\(customName ?? worktree.name), \(kind(of: worktree).lowercased())"]
    if customName != nil { parts.append("branch \(worktree.name)") }
    if isSelected { parts.append("selected") }
    parts.append((state ?? .idle).displayName)
    if let operation {
      parts.append(operation.isRunning ? operation.title : "failed: \(operation.title)")
    }
    if worktree.isLocked { parts.append("locked") }
    if mergeState.showsBadge(with: status) { parts.append(mergeState.summary) }
    if let status, !status.isClean { parts.append(status.summary) }
    if terminalCount > 0 { parts.append(Wording.count(terminalCount, "terminal")) }
    return parts.joined(separator: ", ")
  }

  /// "Main worktree", "Linked worktree", "Bare repository", or the SHA for
  /// a detached one. Also the tooltip on the row's dot.
  public static func kind(of worktree: Worktree) -> String {
    if worktree.isBare { return "Bare repository" }
    if worktree.isDetached { return "Detached at \(worktree.head.prefix(7))" }
    return worktree.isPrimary ? "Main worktree" : "Linked worktree"
  }

  /// A tab in the strip: its title, whether it is the one shown, its state
  /// and whether it is split.
  public static func tab(
    title: String, isActive: Bool, isSplit: Bool, state: SessionState?
  )
    -> String
  {
    var parts = ["\(title), tab"]
    if isActive { parts.append("selected") }
    if isSplit { parts.append("split") }
    if let state { parts.append(state.displayName) }
    return parts.joined(separator: ", ")
  }
}
