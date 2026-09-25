/// Where a project hook runs: before or after git creates or deletes a worktree.
public enum HookStage: String, Sendable {
  case preCreate
  case postCreate
  case preDelete
  case postDelete

  /// Whether the git operation the hook surrounds has happened.
  public var operationHappened: Bool {
    self == .postCreate || self == .postDelete
  }
}
