import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelStatusPollingTests {
  @Test func aCollapsedProjectsWorktreesAreNotReadUntilItOpens() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    let main = try #require(h.worktree(onBranch: "main"))
    h.model.select(main)
    for worktree in [side, main] {
      try "x".write(
        to: worktree.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    }
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.setExpanded(false, for: h.project)
    await h.model.refreshStatuses()
    #expect(h.model.statuses[side.id] == nil)
    #expect(h.model.statuses[main.id]?.changedFiles == 1, "the main one, for its branch")

    h.model.setExpanded(true, for: h.project)
    #expect(h.model.pendingStatusRefreshes.isEmpty, "one capped poll, not a read per row")
    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func openingOneProjectReadsNoOtherProjectsWorktrees() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let other = h.root.appendingPathComponent("other", isDirectory: true)
    try await TestRepository.initialise(at: other, using: h.git)
    try await TestRepository.commitInitial(in: other, using: h.git)
    await h.model.addProject(at: other)
    let otherProject = try #require(h.model.workspace.projects.first { $0.id != h.project.id })
    let otherMain = try #require(h.model.workspace.worktrees(of: otherProject.id).first)
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    h.model.setExpanded(false, for: h.project)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    var unread = WorktreeStatus()
    unread.branch = "main"
    unread.changedFiles = 99
    h.model.statuses = [otherMain.id: unread]

    h.model.setExpanded(true, for: h.project)

    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[otherMain.id] == unread)
  }

  @Test func aPauseInTypingReadsOnlyTheRowsTheFilterBroughtBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    for branch in ["side", "other"] {
      let path = h.root.appendingPathComponent("demo-\(branch)", isDirectory: true)
      _ = try await h.git.run(
        ["worktree", "add", "-q", "-b", branch, path.path], in: h.project.path)
    }
    await h.model.refresh(h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    let other = try #require(h.worktree(onBranch: "other"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.sidebarFilterText = "side"
    await h.model.pendingRevealedRowsRead?.task.value
    for worktree in [side, other] {
      try "x".write(
        to: worktree.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    }
    h.model.statuses = [:]

    h.model.sidebarFilterText = ""
    await h.model.pendingRevealedRowsRead?.task.value

    #expect(h.model.statuses[other.id]?.changedFiles == 1, "brought back, so read")
    #expect(h.model.statuses[side.id] == nil, "on screen all along, so left to the poll")
  }

  @Test func aCollapsedProjectsRowTheFilterShowsIsRead() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]
    h.model.setExpanded(false, for: h.project)

    h.model.sidebarFilterText = "side"
    await h.model.refreshStatuses()

    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func clearingTheFilterReadsTheRowsItBringsBack() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.sidebarFilterText = "nothing-by-this-name"
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.sidebarFilterText = ""

    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func renamingARowOfACollapsedProjectReadsTheRowsItOpens() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    h.model.setExpanded(false, for: h.project)
    try "x".write(
      to: side.path.appendingPathComponent("dirty.txt"), atomically: true, encoding: .utf8)
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.beginRenamingWorktree(side)

    try await waitUntil { h.model.statuses[side.id] != nil }
    #expect(h.model.statuses[side.id]?.changedFiles == 1)
  }

  @Test func anExpandedProjectsRowTheFilterHidesIsNotRead() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    await h.model.createWorktree(branch: "side", basedOn: nil, createBranch: true, in: h.project)
    let side = try #require(h.worktree(onBranch: "side"))
    h.model.select(try #require(h.worktree(onBranch: "main")))
    for pending in h.model.pendingStatusRefreshes.values { pending.cancel() }
    h.model.pendingStatusRefreshes = [:]
    h.model.statuses = [:]

    h.model.sidebarFilterText = "nothing-by-this-name"
    await h.model.refreshStatuses()

    #expect(h.model.statuses[side.id] == nil)
  }

  @Test func aPanesReadAsksNothingOfAWorktreeInAMissingProject() async throws {
    let h = try await GitHarness()
    defer { h.tearDown() }
    let model = try h.modelOnFakeGit("")
    let main = try #require(h.worktree(onBranch: "main"))
    model.missingProjects.insert(h.project.id)

    await model.refreshStatus(of: main.id)

    #expect(!h.gitCalls().contains { $0.contains("status") })
  }
}
