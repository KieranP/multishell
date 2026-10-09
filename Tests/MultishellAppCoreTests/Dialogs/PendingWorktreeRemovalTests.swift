import Foundation
import MultishellCore
import MultishellGitKit
import Testing

@testable import MultishellAppCore

@Suite
struct PendingWorktreeRemovalTests {
  private struct RemovalTestFailure: Error {
    let decision: PendingWorktreeRemoval.Decision
  }

  private let branched = Worktree(
    path: URL(fileURLWithPath: "/trees/feat"),
    projectID: "/repo",
    head: "abc",
    branch: "feat",
  )
  private let detached = Worktree(
    path: URL(fileURLWithPath: "/trees/pinned"),
    projectID: "/repo",
    head: "abc1234",
  )

  private func asked(
    _ worktree: Worktree,
    confirms: Bool,
    alwaysDeletesBranch: Bool,
    mergeState: WorktreeMergeState = .unknown,
  ) throws -> PendingWorktreeRemoval {
    let decision = PendingWorktreeRemoval.decide(
      worktree,
      confirms: confirms,
      alwaysDeletesBranch: alwaysDeletesBranch,
      mergeState: mergeState,
    )
    guard case .ask(let pending) = decision else {
      throw RemovalTestFailure(decision: decision)
    }
    return pending
  }

  @Test func withConfirmationOnTheDialogAsksAboutTheBranchUnlessASettingSettlesIt() throws {
    let pending = try asked(branched, confirms: true, alwaysDeletesBranch: false)
    #expect(pending.choices.count == 2, "one button for the branch, one without it")
    #expect(pending.branchHandling == .offersBoth)
    #expect(pending.choices.map(\.label) == ["Remove Worktree", "Remove Worktree and Branch"])
    #expect(pending.title == "Remove worktree feat?")

    let settled = try asked(branched, confirms: true, alwaysDeletesBranch: true)
    #expect(settled.choices.count == 1)
    #expect(settled.branchHandling == .decided(deletesBranch: true))
    #expect(
      settled.choices.map(\.label) == ["Remove Worktree and Branch"],
      "one button, saying what it does",
    )
  }

  @Test func withConfirmationOffOnlyAnOpenBranchQuestionStillAsks() throws {
    #expect(
      PendingWorktreeRemoval.decide(branched, confirms: false, alwaysDeletesBranch: true)
        == .remove(deletesBranch: true)
    )
    #expect(
      PendingWorktreeRemoval.decide(detached, confirms: false, alwaysDeletesBranch: false)
        == .remove(deletesBranch: false),
      "nothing to ask about a detached worktree",
    )
    let pending = try asked(branched, confirms: false, alwaysDeletesBranch: false)
    #expect(pending.choices.count == 2, "deleting a branch is not undone from the sidebar")
  }

  @Test func aDetachedWorktreeNeverHasItsBranchDeleted() throws {
    let pending = try asked(detached, confirms: true, alwaysDeletesBranch: true)
    #expect(pending.branchHandling == .decided(deletesBranch: false) && pending.choices.count == 1)
    #expect(pending.choices.map(\.label) == ["Remove Worktree"])
    #expect(!pending.message(warning: nil).contains("branch"))
  }

  @Test func aMergedBranchLeadsWithTheButtonThatDeletesItAndSaysWhy() throws {
    let pending = try asked(
      branched,
      confirms: true,
      alwaysDeletesBranch: false,
      mergeState: .merged(.ancestor, into: "origin/main"),
    )
    #expect(pending.choices.map(\.deletesBranch) == [true, false])
    #expect(pending.choices.first?.label == "Remove Worktree and Branch")
    #expect(pending.message(warning: nil).contains("feat is merged into origin/main."))
  }

  @Test func anUpstreamThatHasGoneIsNotEnoughToLeadWithDeletingTheBranch() throws {
    let pending = try asked(
      branched,
      confirms: true,
      alwaysDeletesBranch: false,
      mergeState: .merged(.upstreamGone, into: "origin/main"),
    )
    #expect(
      pending.choices.map(\.deletesBranch) == [false, true],
      "keeping it stays the default",
    )
    #expect(pending.message(warning: nil).contains("likely squash-merged"))
  }

  @Test func aSettledBranchQuestionStillOffersOneButtonWhateverTheMergeState() throws {
    let pending = try asked(
      branched,
      confirms: true,
      alwaysDeletesBranch: true,
      mergeState: .merged(.ancestor, into: "origin/main"),
    )
    #expect(
      pending.choices == [
        PendingWorktreeRemoval.Choice(label: "Remove Worktree and Branch", deletesBranch: true)
      ]
    )
  }
}
