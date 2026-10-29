/// A merge as the user confirmed it in the merge form.
public struct PullRequestMerge: Hashable, Sendable {
  let method: PullRequestMergeMethod
  /// `nil` for a method that takes none.
  let message: PullRequestMergeMessage?
  /// The head the user saw: a push since fails the merge rather than landing
  /// commits nobody looked at.
  let headCommit: String
  /// Turns auto-merge on, for the host to merge once the checks pass.
  public let waitsForChecks: Bool

  public init(
    method: PullRequestMergeMethod,
    message: PullRequestMergeMessage?,
    headCommit: String,
    waitsForChecks: Bool,
  ) {
    self.method = method
    self.message = message
    self.headCommit = headCommit
    self.waitsForChecks = waitsForChecks
  }
}
