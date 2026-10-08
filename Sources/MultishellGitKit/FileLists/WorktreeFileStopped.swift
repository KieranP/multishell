/// The user stopped a list part way. What was placed stays, as a stopped
/// hook's work does; `failures` is what had already gone wrong, unexcused.
public struct WorktreeFileStopped: Error {
  public let failures: [WorktreeFileFailure.PathFailure]
  public let skipped: [String]

  init(failures: [WorktreeFileFailure.PathFailure] = [], skipped: [String] = []) {
    self.failures = failures
    self.skipped = skipped
  }
}
