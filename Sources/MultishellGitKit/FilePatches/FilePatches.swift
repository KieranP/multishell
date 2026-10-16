import Foundation

/// One file's changes against `HEAD` as git prints them, every line in
/// context, in the bytes git wrote: the file may not be UTF-8.
public struct FilePatches: Sendable {
  /// `HEAD` against the file on disk: what a file tab draws.
  public let onDisk: Data
  /// `HEAD` against the index, which says which of those changes are staged.
  public let staged: Data
}
