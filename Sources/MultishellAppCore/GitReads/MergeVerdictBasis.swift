/// What a worktree's merge verdict was computed from, so a refresh finding
/// it unmoved asks git nothing. The branch and its gone upstream are in it.
struct MergeVerdictBasis: Equatable, Sendable {
  let defaultBranchName: String
  let defaultBranchTip: String
  let branch: String
  let branchTip: String
  let upstreamIsGone: Bool
}
