import MultishellCore

extension AppModel {
  /// A cover first, then the selected worktree's operation, groups or
  /// nothing, then the empty state.
  public var detailContent: DetailContent {
    switch detailCover {
    case .agentBoard: return .agentBoard
    case .debugInfo: return .debugInfo
    case nil: break
    }
    guard let worktree = workspace.selectedWorktree else {
      return .noSelection(hasProjects: !workspace.projects.isEmpty)
    }
    if let operation = worktreeOperations[worktree.id] { return .operation(worktree, operation) }
    return workspace.groups(in: worktree.id).isEmpty ? .noTabs(worktree) : .tabGroups(worktree)
  }
}
