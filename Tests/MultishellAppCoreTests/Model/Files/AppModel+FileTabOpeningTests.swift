import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelFileTabOpeningTests {
  @Test func aTextFileOpensInATabAndABinaryOneBeeps() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    try Data([0x89, 0x00]).write(to: main.path.appending(path: "icon.png"))

    await harness.model.openFileAsTab("README.md", in: main.id)
    await harness.model.openFileAsTab("icon.png", in: main.id)
    await harness.model.openFileAsTab("README.md", in: main.id)

    #expect(harness.model.workspace.fileTabs.map(\.path) == ["README.md"])
    #expect(harness.platform.beeps == 1)
    #expect(harness.model.workspace.activeWorkspaceTab(in: main.id)?.fileTab?.path == "README.md")
  }

  @Test func aFileGoneFromDiskIsJudgedOnGitsCopy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    try FileManager.default.removeItem(at: main.path.appending(path: "README.md"))

    await harness.model.openFileAsTab("README.md", in: main.id)

    #expect(harness.model.workspace.fileTabs.map(\.path) == ["README.md"])
  }

  @Test func aLinkInsideTheWorktreeOpensWhatItPointsAtAndOneLeavingItBeeps() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    let files = FileManager.default
    try files.createSymbolicLink(
      atPath: main.path.appending(path: "CLAUDE.md").path,
      withDestinationPath: "README.md",
    )
    let outside = harness.root.appending(path: "outside.txt")
    try "away\n".write(to: outside, atomically: true, encoding: .utf8)
    try files.createSymbolicLink(
      atPath: main.path.appending(path: "away.txt").path,
      withDestinationPath: outside.path,
    )
    _ = await harness.model.refreshStatus(of: main.id)

    await harness.model.openFileAsTab("CLAUDE.md", in: main.id)
    await harness.model.openFileAsTab("away.txt", in: main.id)

    #expect(harness.model.workspace.fileTabs.map(\.path) == ["README.md"])
    #expect(harness.platform.beeps == 1)
  }

  @Test func aCommittedLinkWhoseTargetIsGoneBeeps() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    try FileManager.default.createSymbolicLink(
      atPath: main.path.appending(path: "docs.md").path,
      withDestinationPath: "gone.md",
    )
    _ = try await harness.git.run(["add", "docs.md"], in: main.path)
    _ = try await harness.git.run(["commit", "-q", "-m", "link"], in: main.path)
    _ = await harness.model.refreshStatus(of: main.id)

    await harness.model.openFileAsTab("docs.md", in: main.id)

    #expect(harness.model.workspace.fileTabs.isEmpty)
    #expect(harness.platform.beeps == 1)
  }
}
