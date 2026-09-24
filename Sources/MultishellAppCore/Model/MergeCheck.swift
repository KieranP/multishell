import Foundation
import MultishellCore
import MultishellGitKit

/// What a worktree's merge verdict was computed from, so a refresh finding
/// it unmoved asks git nothing. The branch and its gone upstream are in it.
struct MergeCheck: Equatable, Sendable {
  let base: String
  let baseTip: String
  let branch: String
  let tip: String
  let upstreamIsGone: Bool
}
