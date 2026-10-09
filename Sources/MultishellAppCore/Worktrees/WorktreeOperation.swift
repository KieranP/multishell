import MultishellCore

/// A create or remove running on a worktree, shown in its detail pane so no
/// sheet stays up for a slow hook. A failed stage leaves `failure`.
public struct WorktreeOperation: Equatable, Sendable {
  public let stage: Stage
  /// What the hook or git said, once the stage has failed. `nil` while it
  /// runs.
  public let failure: String?
  /// The stage failed on the timeout, so the title says it did not finish
  /// rather than that it refused.
  let didTimeOut: Bool

  public var isRunning: Bool { failure == nil }

  init(_ stage: Stage, failure: String? = nil, didTimeOut: Bool = false) {
    self.stage = stage
    self.failure = failure
    self.didTimeOut = didTimeOut
  }
}
