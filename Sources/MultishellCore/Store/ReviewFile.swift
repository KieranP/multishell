import Foundation

/// One worktree's review comments as JSON, apart from the state file; see
/// Docs/design/files/review-comments.md.
public struct ReviewFile: Sendable {
  private struct Contents: Codable {
    let worktree: Worktree.ID
    let comments: [ReviewComment]

    init(worktree: Worktree.ID, comments: [ReviewComment]) {
      self.worktree = worktree
      self.comments = comments
    }

    /// Lossy, so a comment this build cannot read costs that comment alone.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      worktree = try container.decode(Worktree.ID.self, forKey: .worktree)
      comments = container.decodeLossy(ReviewComment.self, forKey: .comments)
    }
  }

  private let worktreeID: Worktree.ID
  private let fileURL: URL
  private let order = SaveOrder()

  /// Present, though it may hold nothing this build can read.
  public var existsOnDisk: Bool {
    FileManager.default.fileExists(atPath: fileURL.path)
  }

  /// A change was issued that no write has landed, so the file may be behind.
  public var hasUnsavedChanges: Bool {
    order.hasUnlandedTicket
  }

  /// Named by a digest of the worktree's path, which may be longer than a file name allows.
  public init(worktreeID: Worktree.ID, in directory: URL) {
    self.worktreeID = worktreeID
    let name = FileDigest.sha256(of: Data(worktreeID.utf8))
    self.fileURL = directory.appendingPathComponent("\(name).json", isDirectory: false)
  }

  /// A file that will not read or decode is moved aside, as the state file is,
  /// so the next save cannot write over what the user wrote.
  public func load() throws(UnreadableReviewFile) -> [ReviewComment] {
    guard existsOnDisk else { return [] }
    do {
      let contents = try JSONDecoder().decode(Contents.self, from: try Data(contentsOf: fileURL))
      return contents.worktree == worktreeID ? contents.comments : []
    } catch {
      let backup = BrokenFileBackup.url(for: fileURL)
      let moved = (try? FileManager.default.moveItem(at: fileURL, to: backup)) != nil
      throw UnreadableReviewFile(fileURL: fileURL, backup: moved ? backup : nil, underlying: error)
    }
  }

  public func issueTicket() -> SaveOrder.Ticket {
    order.issue()
  }

  /// No comments removes the file. A ticket older than the last landed writes nothing.
  public func save(_ comments: [ReviewComment], as ticket: SaveOrder.Ticket) throws {
    guard !comments.isEmpty else {
      try order.land(ticket) {
        guard existsOnDisk else { return }
        try FileManager.default.removeItem(at: fileURL)
      }
      return
    }
    let data = try JSONEncoder.forFile().encode(
      Contents(worktree: worktreeID, comments: comments)
    )
    try order.land(ticket) { try data.writeAtomicallyCreatingDirectory(to: fileURL) }
  }
}
