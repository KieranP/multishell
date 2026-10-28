import Foundation
import MultishellCore
import MultishellServices

/// What `multishell worktrees show` prints: its `worktrees list` line, then its
/// row's git status, merge badge, stage under way, pull request and CI run.
struct WorktreeDescription: Encodable, Equatable {
  enum CodingKeys: String, CodingKey {
    case status, isStatusFresh, merge, mergedInto, lastCommit, operation, pullRequest
    case ciRun = "ci"
  }

  /// The counts the row's badge and tooltip read; `summary` is the tooltip.
  struct Status: Encodable, Equatable {
    let branch: String?
    let changedFiles: Int
    let insertions: Int
    let deletions: Int
    let unscoredFiles: Int
    let ahead: Int
    let behind: Int
    let summary: String
  }

  /// The create or remove stage it is in, or failed in.
  struct Operation: Encodable, Equatable {
    let stage: String
    let isRunning: Bool
    let failure: String?
    let didTimeOut: Bool
  }

  /// The pull request its row shows, as `worktrees show` prints it.
  struct PullRequest: Encodable, Equatable {
    let integration: String
    let number: Int
    let title: String
    let url: String
    /// open, draft, closed or merged.
    let state: String
    /// approved, changes-requested, required or not-required.
    let review: String
    /// conflicts, behind-base or blocked, where one holds it back.
    let blocker: String?
    let autoMergesWhenReady: Bool
    /// Merged at a head the branch has since moved past, so no proof it landed.
    let isOutgrown: Bool

    init(_ pullRequest: MultishellServices.PullRequest, integration: String, isOutgrown: Bool) {
      self.integration = integration
      self.isOutgrown = isOutgrown
      number = pullRequest.number
      title = pullRequest.title
      url = pullRequest.url.absoluteString
      state = pullRequest.state.rawValue
      review = pullRequest.review.rawValue
      blocker = pullRequest.blocker?.rawValue
      autoMergesWhenReady = pullRequest.autoMergesWhenReady
    }
  }

  /// The newest CI run of its branch.
  struct CIRun: Encodable, Equatable {
    let integration: String
    /// passed, failed, running, on-hold or cancelled.
    let status: String
    let branch: String
    let commit: String

    init(_ run: MultishellServices.CIRun, integration: String) {
      self.integration = integration
      status = run.status.rawValue
      branch = run.branch
      commit = run.commit
    }
  }

  let entry: WorktreeEntry
  /// `nil` until git has been read.
  let status: Status?
  /// Read for this answer; `false` where git failed or the worktree is busy,
  /// `status` then being the last read.
  let isStatusFresh: Bool
  /// merged, unmerged or unknown.
  let merge: String
  let mergedInto: String?
  let lastCommit: Date?
  let operation: Operation?
  let pullRequest: PullRequest?
  let ciRun: CIRun?

  /// The entry's own keys, then these, in one object.
  func encode(to encoder: any Encoder) throws {
    try entry.encode(to: encoder)
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(status, forKey: .status)
    try container.encode(isStatusFresh, forKey: .isStatusFresh)
    try container.encode(merge, forKey: .merge)
    try container.encodeIfPresent(mergedInto, forKey: .mergedInto)
    try container.encodeIfPresent(lastCommit, forKey: .lastCommit)
    try container.encodeIfPresent(operation, forKey: .operation)
    try container.encodeIfPresent(pullRequest, forKey: .pullRequest)
    try container.encodeIfPresent(ciRun, forKey: .ciRun)
  }
}
