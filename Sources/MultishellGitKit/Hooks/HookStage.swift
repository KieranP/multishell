import MultishellCore

/// Where a project hook runs: before or after git creates or deletes a worktree.
public enum HookStage: String, Sendable {
  case postCreate
  case postDelete
  case preCreate
  case preDelete

  /// Whether the git operation the hook surrounds has happened.
  public var isAfterOperation: Bool {
    self == .postCreate || self == .postDelete
  }

  func script(in settings: ProjectSettings) -> String {
    switch self {
    case .preCreate: settings.preCreateHook
    case .postCreate: settings.postCreateHook
    case .preDelete: settings.preDeleteHook
    case .postDelete: settings.postDeleteHook
    }
  }
}
