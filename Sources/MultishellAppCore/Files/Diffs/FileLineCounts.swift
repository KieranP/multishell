import MultishellGitKit

/// A file's `+N −M` in the Files panel and on its tab's bar, a zero side left
/// out: `+21 −0` on a new file read as noise. The sidebar badge keeps both.
public struct FileLineCounts: Hashable, Sendable {
  public let insertions: Int
  public let deletions: Int

  public var showsInsertions: Bool { insertions > 0 }
  public var showsDeletions: Bool { deletions > 0 }
  public var isEmpty: Bool { !showsInsertions && !showsDeletions }

  public init(insertions: Int, deletions: Int) {
    self.insertions = insertions
    self.deletions = deletions
  }

  /// `nil` for a change with no lines to count.
  init?(_ lines: StatusChange.Lines) {
    guard case .counted(let insertions, let deletions) = lines else { return nil }
    self.init(insertions: insertions, deletions: deletions)
  }
}
