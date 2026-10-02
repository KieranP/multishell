import MultishellCore

struct MergeReadPlan {
  var verdictBases: [Worktree.ID: MergeVerdictBasis] = [:]
  var toAsk: [(id: Worktree.ID, branch: String)] = []
  var unbadgeable: [Worktree.ID] = []
}
