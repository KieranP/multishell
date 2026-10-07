import Foundation

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
    if identifier.hasPrefix(Self.sessionPrefix) {
      guard let id = UUID(uuidString: String(identifier.dropFirst(Self.sessionPrefix.count)))
      else { return nil }
      self = .session(id)
    } else if identifier.hasPrefix(Self.worktreePrefix) {
      self = .worktree(String(identifier.dropFirst(Self.worktreePrefix.count)))
    } else {
      return nil
    }
  }
}
