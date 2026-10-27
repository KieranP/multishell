import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelQuickSwitcherTests {
  @Test func filesAreReadOnlyOnceAScopeOrTextListsThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)

    harness.model.toggleQuickSwitcher(.commands)
    harness.model.setQuickSwitcherScope(.all)
    #expect(harness.model.pendingTrackedFilesReads[main.id] == nil)
    #expect(harness.model.trackedFiles[main.id] == nil)

    harness.model.setQuickSwitcherText("readme")
    try await waitUntil { harness.model.trackedFiles[main.id] != nil }
    #expect(harness.model.trackedFiles[main.id]?.paths == ["README.md"])
  }

  @Test func textOfOnlySpacesReadsNoFilesAndAFailedReadIsNotRetriedOnEveryKey() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let other = try await harness.createWorktree(onBranch: "other")
    harness.model.select(other)
    try FileManager.default.removeItem(at: other.path)
    harness.model.toggleQuickSwitcher(.all)

    harness.model.setQuickSwitcherText(" ")
    #expect(harness.model.pendingTrackedFilesReads[other.id] == nil)

    harness.model.setQuickSwitcherText("r")
    #expect(harness.model.pendingTrackedFilesReads[other.id] != nil)
    try await waitUntil { harness.model.pendingTrackedFilesReads[other.id] == nil }

    harness.model.setQuickSwitcherText("re")
    #expect(harness.model.pendingTrackedFilesReads[other.id] == nil)
  }

  @Test func aReadOfTheSameFilesKeepsTheSearchMadeOverThem() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.toggleQuickSwitcher(.all)
    harness.model.setQuickSwitcherText("readme")
    try await waitUntil { harness.model.trackedFiles[main.id] != nil }
    _ = harness.model.quickSwitcherResults
    try #require(harness.model.fileTreeCache[main.id]?.quickSwitcherSearch != nil)

    harness.model.scheduleTrackedFilesRead(of: main.id)
    try await waitUntil { harness.model.pendingTrackedFilesReads[main.id] == nil }

    #expect(harness.model.fileTreeCache[main.id]?.quickSwitcherSearch != nil)
  }

  @Test func aReadOfChangedFilesLeavesTheSearchToTheListingThatReplacesIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.toggleQuickSwitcher(.files)
    harness.model.setQuickSwitcherText("read")
    try await waitUntil { harness.model.trackedFiles[main.id] != nil }
    _ = harness.model.quickSwitcherResults
    let notes = main.path.appending(path: "reading.md")
    try "notes".write(to: notes, atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "reading.md"], in: main.path)

    harness.model.scheduleTrackedFilesRead(of: main.id)
    try await waitUntil { harness.model.trackedFiles[main.id]?.paths.count == 2 }

    #expect(harness.model.fileTreeCache[main.id]?.quickSwitcherSearch != nil)
    let files = harness.model.quickSwitcherResults.sections.flatMap(\.items).map(\.title)
    #expect(files.contains("reading.md"))
  }

  @Test func aFileThatOpensOpensItsCollapsedProjectInTheSidebar() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.store.setExpanded(false, forProject: main.projectID)
    harness.model.toggleQuickSwitcher(.files)

    harness.model.chooseQuickSwitcherRow(.file(path: "README.md", worktreeID: main.id))

    try await waitUntil { harness.model.workspace.project(main.projectID)?.isExpanded == true }
  }
}
