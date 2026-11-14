import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelAllChangesReadsTests {
  private static func paths(_ harness: GitHarness, _ tab: AllChangesTab) -> [String]? {
    harness.model.allChangesReadings[tab.id]?.files.map(\.path)
  }

  private static func openOnFeature(_ harness: GitHarness) async throws -> (AllChangesTab, Worktree)
  {
    let feature = try await harness.createWorktree(onBranch: "feature")
    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.select(feature)
    let tab = try #require(harness.model.openAllChangesTab(in: feature.id))
    return (tab, feature)
  }

  @Test func aShownTabReadsTheWorktreesChangesWithThePanelShut() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await Self.openOnFeature(harness)
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )

    await harness.model.refreshStatuses()

    try await waitUntil { Self.paths(harness, tab) == ["README.md"] }
    #expect(Self.paths(harness, tab) == ["README.md"])
    #expect(!harness.model.showsFilesPanel)
  }

  @Test func underBranchTheTabAsksForTheBranchReadThePanelWouldMake() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await Self.openOnFeature(harness)
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "one\ntwo\n"],
      in: feature.path,
      using: harness.git,
    )

    harness.model.setChangeScope(.branch)
    await harness.model.refreshStatuses()

    try await waitUntil { Self.paths(harness, tab) == ["work.txt"] }
    #expect(Self.paths(harness, tab) == ["work.txt"])
    #expect(harness.model.branchChanges[feature.id] != nil, "kept with the panel shut")
  }

  @Test func aHiddenTabLetsGoOfItsRowsAndReadsAgainWhenShown() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await Self.openOnFeature(harness)
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { Self.paths(harness, tab) == ["README.md"] }

    harness.model.newShellTab()
    #expect(harness.model.allChangesReadings[tab.id] == nil)

    harness.model.activateTab(tab.id)
    try await waitUntil { Self.paths(harness, tab) == ["README.md"] }
    #expect(Self.paths(harness, tab) == ["README.md"])
  }

  @Test func aStatusListingANewFileOwesAReadOfThatFileAlone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await Self.openOnFeature(harness)
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { Self.paths(harness, tab) == ["README.md"] }
    try await harness.statusReadsSettle(feature)
    try await waitUntil { harness.model.pendingAllChangesReads.isEmpty }
    _ = harness.model.allChangesStaleFiles.take(tab.id)
    try "new\n".write(
      to: feature.path.appending(path: "new.txt"),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.pendingAllChangesReads[tab.id] = Task {}

    await harness.model.refreshStatuses()

    #expect(harness.model.allChangesStaleFiles.take(tab.id) == .paths(["new.txt"]))
  }

  @Test func everythingKeptForAClosedTabGoesWithIt() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await Self.openOnFeature(harness)
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshStatuses()
    try await waitUntil { Self.paths(harness, tab) != nil }

    harness.model.closeTab(tab.id)

    #expect(harness.model.allChangesReadings.isEmpty)
    #expect(harness.model.pendingAllChangesReads.isEmpty)
  }

  @Test func aReadMovesEachFilesCommentsToFollowTheLinesTheyQuote() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, feature) = try await Self.openOnFeature(harness)
    let readme = feature.path.appending(path: "README.md")
    try "kept\nedited\n".write(to: readme, atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    try await waitUntil { Self.paths(harness, tab) == ["README.md"] }
    let comment = ReviewComment(
      path: "README.md",
      side: .onDisk,
      scope: .modified,
      lines: 2...2,
      quote: ["edited"],
      text: "Why?",
    )
    harness.model.addReviewComment(comment, in: feature.id)

    try "new\nkept\nedited\n".write(to: readme, atomically: true, encoding: .utf8)
    harness.model.noteAllChangesTabChanged(tab.id, staleness: .paths(["README.md"]))

    let moved = { harness.model.reviewComments(in: feature.id).first?.lines }
    try await waitUntil { moved() == 3...3 }
    #expect(moved() == 3...3)
  }
}
