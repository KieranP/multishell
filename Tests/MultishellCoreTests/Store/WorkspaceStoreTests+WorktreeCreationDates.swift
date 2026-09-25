import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// The creation date is read off the filesystem on every listing, so a stat
/// that could not answer must not be taken as news.
extension WorkspaceStoreTests {
  private var epoch: Date { Date(timeIntervalSince1970: 1_700_000_000) }

  private func worktree(dated: Date?) -> Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/repos/demo"), projectID: "/repos/demo", head: "abc1234",
      branch: "main", isPrimary: true, createdAt: dated)
  }

  @Test func aDateOnceReadSurvivesAListingThatLostIt() {
    let (store, project, _) = demoStore()
    store.replaceWorktrees([worktree(dated: epoch)], forProject: project.id)
    #expect(store.workspace.worktrees.first?.createdAt == epoch)

    store.replaceWorktrees([worktree(dated: nil)], forProject: project.id)
    #expect(
      store.workspace.worktrees.first?.createdAt == epoch, "the stat failed, the date stands")
  }

  /// The point of keeping it: an undated listing is not a change, so it
  /// costs no save and no re-render.
  @Test func anUndatedListingIsNotAChange() {
    let (store, project, _) = demoStore()
    store.replaceWorktrees([worktree(dated: epoch)], forProject: project.id)
    let counter = ChangeCounter(store)

    store.replaceWorktrees([worktree(dated: nil)], forProject: project.id)
    #expect(counter.changes == 0)
  }

  /// A worktree genuinely recreated at the same path takes the new date:
  /// only a missing one falls back to what was known.
  @Test func aFreshDateAlwaysWins() {
    let (store, project, _) = demoStore()
    store.replaceWorktrees([worktree(dated: epoch)], forProject: project.id)
    let later = epoch.addingTimeInterval(86_400)

    store.replaceWorktrees([worktree(dated: later)], forProject: project.id)
    #expect(store.workspace.worktrees.first?.createdAt == later)
  }
}
