import MultishellCore

/// One branch's merge verdict and what it cost, so re-asking every branch
/// after the trunk moves can be spread over several rounds.
public struct MergeReading: Sendable {
  /// `nil` where a read failed: no verdict, but its cost still counts.
  public let state: WorktreeMergeState?
  public let took: Duration
}
