import Foundation

/// The directory is in the Trash and git still lists the worktree: neither
/// `worktree remove` nor `prune` would let go of the record.
public struct WorktreeForgetFailure: Error, CustomStringConvertible {
  public let path: URL
  public let underlying: any Error

  public var description: String {
    "\(path.path) is gone but git still lists it: \(underlying)"
  }
}
