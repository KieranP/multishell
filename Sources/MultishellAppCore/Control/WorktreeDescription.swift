import Foundation
import MultishellCore

/// What `multishell worktrees show` prints: its line of `worktrees list`, and
/// what its row shows beside it: git's status, the merge badge, a stage under way.
struct WorktreeDescription: Encodable, Equatable {
  enum CodingKeys: String, CodingKey {
    case status, isStatusFresh, merge, mergedInto, lastCommit, operation
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
  }
}
