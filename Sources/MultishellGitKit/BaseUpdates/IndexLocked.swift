/// A write that found `index.lock` taken, by an agent's git or the user's.
/// Never retried: the holder may be mid-commit.
public struct IndexLocked: Error, CustomStringConvertible {
  /// What git said, naming the lock file.
  public let message: String

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { message }

  /// The file's name, not git's sentence around it, which a locale translates.
  static func isNamed(in message: String) -> Bool {
    message.contains("index.lock")
  }
}
