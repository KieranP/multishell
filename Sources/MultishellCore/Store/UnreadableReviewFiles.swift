/// More than one worktree's review file would not read at launch, said in one
/// alert where an alert each would leave only the last on screen.
public struct UnreadableReviewFiles: Error {
  public let files: [UnreadableReviewFile]

  public init(files: [UnreadableReviewFile]) {
    self.files = files
  }
}
