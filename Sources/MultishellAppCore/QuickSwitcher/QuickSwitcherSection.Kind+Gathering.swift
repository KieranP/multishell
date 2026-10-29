import MultishellCore

/// What a section gathers, as `ui switcher` prints it beside the kind.
extension QuickSwitcherSection.Kind {
  /// The worktree a files section lists.
  var worktreeName: String? {
    switch self {
    case .files(let name), .changedFiles(let name): name
    case .waiting, .recent, .places, .commands, .worktrees, .tabs, .agents: nil
    }
  }

  /// The state an agents section gathers.
  var state: SessionState? {
    if case .agents(let state) = self { state } else { nil }
  }
}
