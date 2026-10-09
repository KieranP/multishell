import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelRevealedRowsTests {
  @Test func aPauseInTypingReadsOnlyTheRowsTheFilterBroughtBack() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    for branch in ["side", "other"] {
      let path = harness.root.appendingPathComponent("demo-\(branch)", isDirectory: true)
      try await harness.addOutsideTheApp(branch, at: path)
    }
    await harness.model.refreshWorktrees(of: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    let other = try #require(harness.worktree(onBranch: "other"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.sidebarFilterText = "side"
    await harness.model.pendingRevealedRowsRead?.task.value
    for worktree in [side, other] {
      try harness.dirty(worktree)
    }
    harness.model.statuses = [:]

    harness.model.sidebarFilterText = ""
    await harness.model.pendingRevealedRowsRead?.task.value

    #expect(harness.model.statuses[other.id]?.changedFiles == 1, "brought back, so read")
    #expect(harness.model.statuses[side.id] == nil, "on screen all along, so left to the poll")
  }

  @Test func aTextChangeReadsTheRowsOfAProjectCollapsedUnderTheOldText() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.root.appendingPathComponent("demo-side", isDirectory: true)
    try await harness.addOutsideTheApp("side", at: path)
    await harness.model.refreshWorktrees(of: harness.project)
    let side = try #require(harness.worktree(onBranch: "side"))
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    harness.model.sidebarFilterText = "side"
    await harness.model.pendingRevealedRowsRead?.task.value
    harness.model.toggleExpansion(of: harness.project)
    try harness.dirty(side)
    harness.clearStatuses()

    harness.model.sidebarFilterText = "sid"
    await harness.model.pendingRevealedRowsRead?.task.value

    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func clearingTheFilterReadsTheRowsItBringsBack() async throws {
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
    harness.model.sidebarFilterText = "nothing-by-this-name"
    try harness.dirty(side)
    harness.clearStatuses()

    harness.model.sidebarFilterText = ""

    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[side.id]?.changedFiles == 1)
  }
}
