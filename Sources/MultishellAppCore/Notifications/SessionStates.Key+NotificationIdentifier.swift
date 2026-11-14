import Foundation
import MultishellCore

extension SessionStates.Key {
  private static let sessionPrefix = "session:"
  private static let worktreePrefix = "worktree:"

  /// Stable for the life of a pane and distinct across the two kinds of key,
  /// the prefix saying which without relying on a path never being a UUID.
  public var notificationIdentifier: String {
    switch self {
    case .session(let id): Self.sessionPrefix + id.uuidString
    case .worktree(let id): Self.worktreePrefix + id
    }
  }

  /// The key a banner was posted about, read back off its identifier.
  public init?(notificationIdentifier identifier: String) {
    if let uuid = identifier.removingPrefix(Self.sessionPrefix) {
      guard let id = UUID(uuidString: uuid) else { return nil }
      self = .session(id)
    } else if let path = identifier.removingPrefix(Self.worktreePrefix) {
      self = .worktree(path)
    } else {
      return nil
    }
  }
}
