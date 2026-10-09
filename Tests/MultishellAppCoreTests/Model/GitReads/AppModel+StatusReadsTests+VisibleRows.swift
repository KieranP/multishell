import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelStatusReadsTests {
  @Test func aCollapsedProjectsWorktreesAreNotReadUntilItOpens() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let side = try #require(harness.worktree(onBranch: "side"))
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    for worktree in [side, main] {
      try harness.dirty(worktree)
    }
    harness.clearStatuses()

    harness.model.setExpanded(false, for: harness.project)
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[side.id] == nil)
    #expect(harness.model.statuses[main.id]?.changedFiles == 1, "the main one, for its branch")

    harness.model.setExpanded(true, for: harness.project)
    #expect(harness.model.pendingStatusRefreshes.isEmpty, "one capped poll, not a read per row")
    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func openingOneProjectReadsNoOtherProjectsWorktrees() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let otherProject = try await harness.addSecondProject()
    let otherMain = try #require(harness.model.workspace.worktrees(of: otherProject.id).first)
    await harness.model.createWorktree(
      branch: "side",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    try harness.dirty(side)
    harness.model.setExpanded(false, for: harness.project)
    harness.clearStatuses()
    var unread = WorktreeStatus()
    unread.branch = "main"
    unread.changedFiles = 99
    harness.model.statuses = [otherMain.id: unread]

    harness.model.setExpanded(true, for: harness.project)

    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[otherMain.id] == unread)
  }

  @Test func aCollapsedProjectsRowTheFilterShowsIsRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    try harness.dirty(side)
    harness.clearStatuses()
    harness.model.setExpanded(false, for: harness.project)

    harness.model.sidebarFilterText = "side"
    await harness.model.refreshStatuses()

    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func aRowCollapsedUnderTheFilterIsNotReadAndExpandingReadsIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.root.appendingPathComponent("demo-side", isDirectory: true)
    try await harness.addOutsideTheApp("side", at: path)
    await harness.model.refreshWorktrees(of: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.sidebarFilterText = "side"
    await harness.model.pendingRevealedRowsRead?.task.value
    try harness.dirty(side)
    harness.clearStatuses()

    harness.model.toggleExpansion(of: harness.project)
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[side.id] == nil)

    harness.model.toggleExpansion(of: harness.project)
    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func renamingARowOfACollapsedProjectReadsTheRowsItOpens() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.setExpanded(false, for: harness.project)
    try harness.dirty(side)
    harness.clearStatuses()

    harness.model.beginRenamingWorktree(side)

    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func anExpandedProjectsRowTheFilterHidesIsNotRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.createWorktree(
      branch: "side",
      basedOn: nil,
      createsBranch: true,
      in: harness.project,
    )
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.clearStatuses()

    harness.model.sidebarFilterText = "nothing-by-this-name"
    await harness.model.refreshStatuses()

    #expect(harness.model.statuses[side.id] == nil)
  }
}
