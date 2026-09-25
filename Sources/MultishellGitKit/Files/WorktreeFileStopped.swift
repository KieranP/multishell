/// The user stopped a list part way. What was placed stays, as a stopped
/// hook's work does; `failures` is what had already gone wrong, unexcused.
public struct WorktreeFileStopped: Error {
  public let failures: [WorktreeFileFailure.Item]
  public let skipped: [String]

  init(failures: [WorktreeFileFailure.Item] = [], skipped: [String] = []) {
    self.failures = failures
    self.skipped = skipped
  }
}
