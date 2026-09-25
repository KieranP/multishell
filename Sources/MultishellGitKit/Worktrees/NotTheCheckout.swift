import Foundation

/// Something other than the worktree sits at its path, and git will not let
/// go of the record while it does; the directory is left alone.
public struct NotTheCheckout: Error, CustomStringConvertible {
  public let path: URL

  init(path: URL) { self.path = path }

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "\(path.path) is not this worktree's checkout" }
}
