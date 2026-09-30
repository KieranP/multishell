import MultishellCore

struct MergeCheckPlan {
  var checks: [Worktree.ID: MergeCheck] = [:]
  var toAsk: [(id: Worktree.ID, branch: String)] = []
  var unbadgeable: [Worktree.ID] = []
}
