import Foundation

/// One thing the PR or CI page can send. A rerun, a push or a new comment
/// changes its key, so it comes back unsent and as it starts.
public enum HandoffItemID: Hashable, Sendable {
  /// Two checks can share a link, and some keep theirs across a push.
  case check(name: String, link: URL?, headCommit: String)
  /// A failed job of a CI run by its place, two workflows able to share a name,
  /// and the provider's id for it, which a rerun replaces.
  case ciJob(runID: String, position: CIJobPosition, jobID: String?)
  /// What a failed run's report says that names no listed job, by its text's hash,
  /// which a rerun under the same id changes; hashed once, not at every lookup.
  case ciRunOutput(runID: String, textHash: Int)
  /// An unresolved thread and its newest comment.
  case thread(id: String, newestCommentID: String)

  /// Which read lists it: only that read, once answered, can say it is gone.
  var source: HandoffItemSource {
    switch self {
    case .check: .checks
    case .thread: .threads
    case .ciJob, .ciRunOutput: .ciRun
    }
  }
}
