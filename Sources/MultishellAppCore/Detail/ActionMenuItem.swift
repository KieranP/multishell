import MultishellCore

/// One row of a worktree's play button menu.
public struct ActionMenuItem: Equatable, Identifiable, Sendable {
  public let name: String
  let state: ActionRunState
  public let keys: KeyCombination?

  public var id: String { name }

  /// The dot beside the row's name, as on its tab; none while idle.
  public var markedState: SessionState? {
    switch state {
    case .running: .running
    case .done: .done
    case .failed: .failed
    case .idle: nil
    }
  }
}
