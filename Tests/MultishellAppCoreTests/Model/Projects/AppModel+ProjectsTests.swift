import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelProjectsTests {
  @Test func addingARepositoryDiscoversItsMainWorktreeAndArmsTheWatcher() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    #expect(harness.model.workspace.projects.count == 1)
    #expect(harness.model.presentedError == nil)
    let worktrees = harness.model.workspace.worktrees(of: harness.project.id)
    #expect(worktrees.map(\.branch) == ["main"])
    #expect(worktrees[0].isPrimary)
    #expect(harness.watcher.watched.map(\.lastPathComponent) == [".git"])
  }

  @Test func addingASubdirectoryIsTheSameProject() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let sources = harness.project.path.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)

    await harness.model.addProject(at: sources)

    #expect(harness.model.workspace.projects.count == 1, "identity is the main worktree's path")
  }

  @Test func addingSomethingThatIsNotARepositoryIsRefused() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }

    await harness.model.addProject(at: harness.root)

    #expect(harness.model.workspace.projects.count == 1)
    #expect(harness.model.presentedError?.title == "Not a git repository")
  }

  @Test func aBareCloneIsAddedAsAProjectWithItsBareEntryFirst() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (bare, checkout) = try await TestRepository.bareClone(
      of: harness.project.path, in: harness.root, worktree: "checkout", using: harness.git)

    await harness.model.addProject(at: checkout)

    #expect(harness.model.presentedError == nil)
    let project = try #require(harness.model.workspace.project(bare.standardizedFileURL.path))
    #expect(project.name == "repo")
    let worktrees = harness.model.workspace.worktrees(of: project.id)
    #expect(worktrees.map(\.isBare) == [true, false])
    #expect(worktrees[0].isPrimary && worktrees[1].branch == "main")
    await harness.model.refreshStatuses()
    #expect(harness.model.statuses[worktrees[0].id] == nil, "no status poll for the bare entry")
    #expect(harness.model.statuses[worktrees[1].id] != nil)
  }

  @Test func aCancelledDirectoryPickerAddsNothing() async {
    let harness = Harness()
    harness.platform.directoryToChoose = nil
    await harness.model.addProjectFromPicker()
    #expect(harness.model.workspace.projects.count == 1)
  }
}
