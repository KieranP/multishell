import MultishellCore

/// What a project row draws in its icon's slot: a running fetch over its
/// collapsed worktrees' state, and either over the icon.
public enum ProjectRowSlot: Equatable, Sendable {
  case fetching
  case icon
  case state(SessionState)

  public init(isFetching: Bool, state: SessionState?) {
    if isFetching {
      self = .fetching
    } else if let state {
      self = .state(state)
    } else {
      self = .icon
    }
  }
}
