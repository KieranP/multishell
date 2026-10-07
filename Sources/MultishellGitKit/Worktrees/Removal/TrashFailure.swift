import Foundation

/// The platform could not move the worktree directory to the Trash. The
/// worktree is still there and still registered.
public struct TrashFailure: Error, CustomStringConvertible {
  public let path: URL
  public let underlying: any Error

  public var description: String {
    "\(path.path) could not be moved to the Trash: \(underlying)"
  }
}
