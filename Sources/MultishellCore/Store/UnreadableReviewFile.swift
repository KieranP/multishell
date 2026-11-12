import Foundation

/// A worktree's review file would not read or decode. It was moved to `backup`,
/// or stayed at `fileURL` where it could not be moved.
public struct UnreadableReviewFile: Error {
  public let fileURL: URL
  public let backup: URL?
  public let underlying: any Error
}
