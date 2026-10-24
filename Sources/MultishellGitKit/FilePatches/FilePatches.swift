import Foundation

/// One file's changes as git prints them, every line in context, in the bytes
/// git wrote: the file may not be UTF-8.
public struct FilePatches: Sendable {
  /// The commit against the file on disk: what a file tab draws.
  public let onDisk: Data
  /// `HEAD` against the index, which says which of those changes are staged;
  /// `nil` against an older commit, whose changes the index holds too.
  public let staged: Data?
}
