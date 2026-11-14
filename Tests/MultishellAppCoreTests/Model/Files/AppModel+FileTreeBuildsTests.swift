import Foundation
import MultishellCore
import MultishellServices
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFileTreeBuildsTests {
  private static func modified(_ count: Int, kind: StatusChange.Kind = .modified) -> WorktreeStatus
  {
    var status = WorktreeStatus()
    status.setChanges(
      (0..<count).map { number in
        StatusChange(
          path: "src/file\(number).txt",
          kind: kind,
          lines: .counted(insertions: 1, deletions: 0),
        )
      }
    )
    return status
  }

  @Test func aLargeListingIsBuiltOffTheMainActorAndShownOnceBuilt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)

    let first = harness.model.fileTreeRows(of: main.id)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }

    #expect(first.isEmpty, "built in place, which held the main actor")
    #expect(harness.model.fileTreeRows(of: main.id).map(\.name) == ["src"])
  }

  @Test func aLargeChangeSetIsBuiltOffTheMainActorAndShownOnceBuilt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.changes)
    var status = Self.modified(30_000)
    harness.model.statuses[main.id] = status

    let first = harness.model.fileTreeRows(of: main.id)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }

    #expect(first.isEmpty, "built in place, which held the main actor")
    #expect(harness.model.fileTreeRows(of: main.id).first?.name == "src")
    #expect(harness.model.filesPanelSummary(of: main.id).changedFiles == 30_000)

    status.setChanges(
      status.changes.map { change in
        StatusChange(
          path: change.path,
          kind: change.kind,
          lines: .counted(insertions: 2, deletions: 0),
        )
      }
    )
    harness.model.statuses[main.id] = status
    #expect(!harness.model.fileTreeRows(of: main.id).isEmpty)
    #expect(harness.model.pendingFileTreeChanges[main.id] == nil, "a count moving keeps the set")
  }

  @Test func aPanelWaitingOnALargeListingAndChangeSetDrawsThemOnceBothLand() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.changes)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)
    harness.model.statuses[main.id] = Self.modified(30_000)

    let renderer = FilesPanelRenderer(harness.model, showing: main.id)
    #expect(renderer.rows.isEmpty)
    try await waitUntil { !renderer.rows.isEmpty }

    #expect(!renderer.rows.isEmpty, "the second build to land redrew the panel")
  }

  @Test func aFilterTypedWhileALargeListingBuildsIsDrawnOnceItLands() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)
    let renderer = FilesPanelRenderer(harness.model, showing: main.id)

    harness.model.setFilesPanelFilterText("file1", in: main.id)
    try await waitUntil { !renderer.rows.isEmpty }

    #expect(!renderer.rows.isEmpty, "the landing redrew the filtered panel")
  }

  @Test func theFooterCountsTheChangedPathsWhileTheirSetBuilds() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.statuses[main.id] = Self.modified(30_000)

    let summary = harness.model.filesPanelSummary(of: main.id)

    #expect(harness.model.pendingFileTreeChanges[main.id] != nil)
    #expect(summary.changedFiles == 30_000)
  }

  @Test func aListingLargeOnlyThroughAReadSubmoduleBuildsOffTheMainActor() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 10)
    harness.model.submoduleReadings[main.id] = [
      "sub": SubmoduleReading(tracked: .sample(count: 30_000), status: nil)
    ]

    _ = harness.model.fileTreeRows(of: main.id)

    #expect(harness.model.pendingFileTreeListings[main.id] != nil)
  }

  @Test func aListingLargeOnlyThroughStagedDeletionsBuildsOffTheMainActor() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 10)
    harness.model.statuses[main.id] = Self.modified(30_000, kind: .deleted)

    _ = harness.model.fileTreeRows(of: main.id)

    #expect(harness.model.pendingFileTreeListings[main.id] != nil)
  }

  @Test func rendersWhileALargeListingBuildsReuseOneTreeAndItsRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)

    let first = harness.model.fileTreeRows(of: main.id)
    let kept = harness.model.fileTreeCache[main.id]

    #expect(harness.model.pendingFileTreeListings[main.id] != nil)
    #expect(kept?.rows?.rows == first)
    _ = harness.model.filesPanelSummary(of: main.id)
    #expect(harness.model.fileTreeCache[main.id]?.rows?.rows == first)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }
    #expect(harness.model.fileTreeRows(of: main.id).map(\.name) == ["src"])
  }

  @Test func sourcesThatRevertWhileABuildRunsShowTheirOwnRows() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)
    try await waitUntil { !harness.model.fileTreeRows(of: main.id).isEmpty }
    let clean = harness.model.statuses[main.id]
    var dirty = WorktreeStatus()
    dirty.setChanges([
      StatusChange(
        path: "src/file1.txt",
        kind: .deleted,
        lines: .counted(insertions: 0, deletions: 1),
      )
    ])
    harness.model.statuses[main.id] = dirty
    #expect(harness.model.fileTreeRows(of: main.id).first?.holdsChange == true)

    harness.model.statuses[main.id] = clean

    #expect(harness.model.fileTreeRows(of: main.id).first?.holdsChange == false)
  }

  @Test func aStatusThatRevertsWhileALargeChangeSetBuildsDrawsTheKeptSetAndDropsTheBuild()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.changes)
    harness.model.statuses[main.id] = Self.modified(3)
    _ = harness.model.fileTreeRows(of: main.id)
    harness.model.statuses[main.id] = Self.modified(30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    harness.model.statuses[main.id] = Self.modified(3)

    #expect(harness.model.fileTreeRows(of: main.id).count == 4, "src and its three files")
    #expect(harness.model.fileTreeCache[main.id]?.awaitsChanges == false)
    try await waitUntil { harness.model.pendingFileTreeChanges[main.id] == nil }
    #expect(harness.model.pendingFileTreeChanges[main.id] == nil)
    #expect(harness.model.fileTreeChanges[main.id] == nil, "landed with nothing waiting for it")
  }

  @Test func aChangeSetThatFlipsAwayAndBackKeepsItsOneBuild() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.statuses[main.id] = Self.modified(3)
    _ = harness.model.fileTreeRows(of: main.id)
    harness.model.statuses[main.id] = Self.modified(30_000)
    _ = harness.model.fileTreeRows(of: main.id)
    let first = try #require(harness.model.pendingFileTreeChanges[main.id])

    harness.model.statuses[main.id] = Self.modified(4)
    _ = harness.model.fileTreeRows(of: main.id)
    harness.model.statuses[main.id] = Self.modified(30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    #expect(harness.model.pendingFileTreeChanges[main.id] == first, "a started build runs on")
  }

  @Test func aChangeSetThatShrinksLetsGoOfTheLargeOneBuiltForIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.setFilesPanelMode(.changes)
    harness.model.statuses[main.id] = Self.modified(30_000)
    let renderer = FilesPanelRenderer(harness.model, showing: main.id)
    try await waitUntil { renderer.rows.count > 30_000 }
    try #require(renderer.rows.count > 30_000)

    harness.model.statuses[main.id] = Self.modified(3)
    try await waitUntil { renderer.rows.count == 4 }

    #expect(renderer.rows.count == 4, "src and its three files")
    #expect(harness.model.fileTreeChanges[main.id] == nil)
  }

  @Test func aListingThatShrinksLetsGoOfTheLargeOneBuiltForIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)
    let renderer = FilesPanelRenderer(harness.model, showing: main.id)
    try await waitUntil { !renderer.rows.isEmpty }
    try #require(!renderer.rows.isEmpty)

    harness.model.trackedFiles[main.id] = .sample(count: 3)
    try await waitUntil { harness.model.fileTreeCache[main.id]?.tree.listing.filePaths.count == 3 }

    #expect(harness.model.fileTreeCache[main.id]?.tree.listing.filePaths.count == 3)
    #expect(harness.model.fileTreeListings[main.id] == nil)
  }

  @Test func aLargeBuildOvertakenByASmallListingIsNotKept() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    harness.model.trackedFiles[main.id] = .sample(count: 30_000)
    _ = harness.model.fileTreeRows(of: main.id)

    harness.model.trackedFiles[main.id] = .sample(count: 3)
    _ = harness.model.fileTreeRows(of: main.id)

    try await waitUntil { harness.model.pendingFileTreeListings[main.id] == nil }
    #expect(harness.model.pendingFileTreeListings[main.id] == nil)
    #expect(harness.model.fileTreeListings[main.id] == nil)
  }
}
