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
    try Data([0x89, 0x00]).write(to: main.path.appending(path: "blob.bin"))

    await harness.model.openFileAsTab("README.md", in: main.id)
    await harness.model.openFileAsTab("blob.bin", in: main.id)
    await harness.model.openFileAsTab("README.md", in: main.id)

    #expect(harness.model.workspace.fileTabs.map(\.path) == ["README.md"])
    #expect(harness.platform.beeps == 1)
    #expect(harness.model.workspace.activeWorkspaceTab(in: main.id)?.fileTab?.path == "README.md")
  }

  @Test func aFileNamedAsAnImageOpensInATabOnDiskOrGone() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    let logo = main.path.appending(path: "logo.png")
    try await harness.commitFile(
      "logo.png",
      holding: FakeImage.bytes(width: 2, height: 2),
      in: main,
    )
    try FakeImage.bytes(width: 3, height: 3).write(to: main.path.appending(path: "new.png"))
    try FileManager.default.removeItem(at: logo)
    _ = await harness.model.refreshStatus(of: main.id)

    await harness.model.openFileAsTab("new.png", in: main.id)
    await harness.model.openFileAsTab("logo.png", in: main.id)

    #expect(harness.model.workspace.fileTabs.map(\.path) == ["new.png", "logo.png"])
    #expect(harness.platform.beeps == 0)
  }

  @Test func aFileGoneFromASubmoduleIsJudgedOnTheSubmodulesCopy() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let main = try #require(harness.worktree(onBranch: "main"))
    harness.model.select(main)
    let library = harness.root.appending(path: "library", directoryHint: .isDirectory)
    try await TestRepository.initialise(at: library, withFirstCommit: true, using: harness.git)
    try await TestRepository.commit(
      "logo",
      files: ["logo.png": "pixels\n", "notes.txt": "hello\n"],
      in: library,
      using: harness.git,
    )
    _ = try await harness.git.run(
      ["-c", "protocol.file.allow=always", "submodule", "add", "-q", library.path, "vendor/lib"],
      in: main.path,
    )
    _ = try await harness.git.run(["commit", "-q", "-m", "submodule"], in: main.path)
    let inside = main.path.appending(path: "vendor/lib")
    try FileManager.default.removeItem(at: inside.appending(path: "logo.png"))
    try FileManager.default.removeItem(at: inside.appending(path: "notes.txt"))

    await harness.model.openFileAsTab("vendor/lib/logo.png", in: main.id)
    await harness.model.openFileAsTab("vendor/lib/notes.txt", in: main.id)

    #expect(
      harness.model.workspace.fileTabs.map(\.path) == [
        "vendor/lib/logo.png", "vendor/lib/notes.txt",
      ]
    )
    #expect(harness.platform.beeps == 0)
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
