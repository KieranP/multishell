/// A review comment the command line asks for, on lines of a file shown in a tab.
public struct ReviewCommentOrder: Codable, Equatable, Sendable {
  /// The worktree's `ControlID`; `nil` for the one in view.
  public let worktreeID: String?
  /// Relative to the worktree, as the tab keys its file.
  public let path: String
  public let side: DiffSide
  public let lines: ClosedRange<Int>
  public let text: String

  public init(
    worktreeID: String?,
    path: String,
    side: DiffSide,
    lines: ClosedRange<Int>,
    text: String,
  ) {
    self.worktreeID = worktreeID
    self.path = path
    self.side = side
    self.lines = lines
    self.text = text
  }
}
