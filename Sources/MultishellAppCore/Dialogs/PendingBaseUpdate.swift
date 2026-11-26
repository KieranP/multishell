import MultishellCore
import MultishellGitKit

/// Merge from Base or Rebase onto Base's question before it runs: the agent may
/// edit or commit under it, or the rebase rewrites commits the remote holds.
public struct PendingBaseUpdate: Identifiable, Equatable, Sendable {
  let worktree: Worktree
  let method: UpdateMethod
  let base: DefaultBranch
  /// The agent working there, by name, or `nil` where none is.
  let workingAgentName: String?
  /// Only a rebase rewrites, so a merge never asks for this.
  let rewritesPushedBranch: Bool

  public var id: Worktree.ID { worktree.id }

  /// What a Confirm agrees to, which a run after the fetch holds the reasons it finds to.
  var consent: BaseUpdateConsent {
    BaseUpdateConsent(
      overWorkingAgent: workingAgentName != nil,
      rewritingPushedBranch: rewritesPushedBranch,
    )
  }

  /// A reason `consent` does not cover, which asks, or refuses, before git writes.
  func exceeds(_ consent: BaseUpdateConsent) -> Bool {
    (workingAgentName != nil && !consent.overWorkingAgent)
      || (rewritesPushedBranch && !consent.rewritingPushedBranch)
  }
}
