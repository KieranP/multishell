import Foundation
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeCoordinatorRemovalTests {
  private static let allowingFile = ["-c", "protocol.file.allow=always"]

  @Test func aWorktreeHoldingAnotherWorktreeIsRefusedAndBothStay() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let outer = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "outer",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    let inner = outer.appendingPathComponent(".worktrees/inner", isDirectory: true)
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "-b", "inner", inner.path],
      in: outer,
    )
    try "work\n".write(
      to: inner.appendingPathComponent("wip.txt"),
      atomically: true,
      encoding: .utf8,
    )
    let worktree = try await fixture.worktree(onBranch: "outer")

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(worktree, in: fixture.project)
    }

    #expect(FileManager.default.fileExists(atPath: inner.appendingPathComponent("wip.txt").path))
    #expect(try await fixture.git.list(fixture.project).count == 3)
  }

  @Test(arguments: ["sub", "sub\tx"])
  func aWorktreeWhoseInitialisedSubmoduleHoldsNothingUnpushedIsRemoved(
    at submodule: String
  )
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let held = try await worktreeWithInitialisedSubmodule(at: submodule, in: fixture)

    try await fixture.coordinator.removeUnlinking(held.worktree, in: fixture.project)

    #expect(!FileManager.default.fileExists(atPath: held.path.path))
    #expect(try await fixture.git.list(fixture.project).count == 1)
  }

  @Test(arguments: ["sub", "sub\tx"])
  func aWorktreeWhoseSubmoduleHasACommitOnNoRemoteIsRefusedAndKeepsItsRepository(
    at submodule: String
  )
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let held = try await worktreeWithInitialisedSubmodule(at: submodule, in: fixture)
    try await commitFile(named: "local.txt", in: held.checkout, with: fixture)
    let repository = try #require(WorktreeGit.recordDirectoryFromGitFile(in: held.checkout))

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(held.worktree, in: fixture.project)
    }

    #expect(
      FileManager.default.fileExists(atPath: held.checkout.appendingPathComponent(".git").path)
    )
    #expect(FileManager.default.fileExists(atPath: repository.appendingPathComponent("HEAD").path))
    #expect(try await fixture.git.list(fixture.project).count == 2)
  }

  @Test func aWorktreeWhoseSubmoduleHasAnUntrackedFileIsRefused() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let held = try await worktreeWithInitialisedSubmodule(at: "sub", in: fixture)
    try "draft\n".write(
      to: held.checkout.appendingPathComponent("draft.txt"),
      atomically: true,
      encoding: .utf8,
    )

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(held.worktree, in: fixture.project)
    }

    #expect(
      FileManager.default.fileExists(atPath: held.checkout.appendingPathComponent("draft.txt").path)
    )
  }

  @Test func aWorktreeWhoseSubmoduleStashedWorkIsRefused() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let held = try await worktreeWithInitialisedSubmodule(at: "sub", in: fixture)
    try await stashAChange(in: held.checkout, with: fixture)

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(held.worktree, in: fixture.project)
    }
  }

  @Test func aWorktreeWhoseNestedSubmoduleStashedWorkIsRefused() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let inner = fixture.root.appendingPathComponent("inner-upstream", isDirectory: true)
    try await TestRepository.initialise(at: inner, withFirstCommit: true)
    let upstream = fixture.root.appendingPathComponent("upstream", isDirectory: true)
    try await TestRepository.initialise(at: upstream, withFirstCommit: true)
    _ = try await fixture.runner.run(
      Self.allowingFile + ["submodule", "add", "-q", inner.path, "inner"],
      in: upstream,
    )
    _ = try await fixture.runner.run(["commit", "-q", "-m", "add inner"], in: upstream)
    let held = try await worktreeWithInitialisedSubmodule(
      at: "sub",
      in: fixture,
      from: upstream,
    )
    let nested = held.checkout.appendingPathComponent("inner", isDirectory: true)
    try await stashAChange(in: nested, with: fixture)

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.removeUnlinking(held.worktree, in: fixture.project)
    }
  }

  @Test func aCheckoutBackDuringThePreDeleteHookWithUnpushedSubmoduleWorkIsRefused() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    let held = try await worktreeWithInitialisedSubmodule(at: "sub", in: fixture)
    try await commitFile(named: "local.txt", in: held.checkout, with: fixture)
    let (worktree, path) = (held.worktree, held.path)
    let away = try Scratch.directory("unmounted").appendingPathComponent("feature")
    defer { Scratch.remove(away.deletingLastPathComponent()) }
    try FileManager.default.moveItem(at: path, to: away)
    project.settings = ProjectSettings(
      preDeleteHook: "mv '\(away.path)' \"$MULTISHELL_WORKTREE_PATH\""
    )

    await #expect(throws: WorktreeHoldsOtherWork.self) {
      try await fixture.coordinator.remove(
        worktree,
        in: project,
        trash: { url in try FileManager.default.removeItem(at: url) },
        port: nil,
        shellPath: "/bin/sh",
      )
    }

    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("sub/.git").path))
    #expect(try await fixture.git.list(fixture.project).count == 2)
  }

  @Test func aWorktreeWhoseSubmodulesWereDeinitialisedIsRemovedAsGitWould() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let held = try await worktreeWithInitialisedSubmodule(at: "sub", in: fixture)
    try await stashAChange(in: held.checkout, with: fixture)
    _ = try await fixture.runner.run(["submodule", "deinit", "-q", "--all"], in: held.path)

    try await fixture.coordinator.removeUnlinking(held.worktree, in: fixture.project)

    #expect(try await fixture.git.list(fixture.project).count == 1)
  }

  private func worktreeWithInitialisedSubmodule(
    at submodule: String,
    in fixture: RepositoryFixture,
    from upstream: URL? = nil,
  ) async throws -> (worktree: Worktree, path: URL, checkout: URL) {
    let source: URL
    if let upstream {
      source = upstream
    } else {
      source = fixture.root.appendingPathComponent("upstream", isDirectory: true)
      try await TestRepository.initialise(at: source, withFirstCommit: true)
    }
    _ = try await fixture.runner.run(
      Self.allowingFile + ["submodule", "add", "-q", source.path, submodule],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(["commit", "-q", "-m", "add sub"], in: fixture.project.path)
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "feature",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    _ = try await fixture.runner.run(
      Self.allowingFile + ["submodule", "update", "--init", "--recursive", "-q"],
      in: path,
    )
    let worktree = try await fixture.worktree(onBranch: "feature")
    return (worktree, path, path.appendingPathComponent(submodule, isDirectory: true))
  }

  private func commitFile(
    named name: String,
    in checkout: URL,
    with fixture: RepositoryFixture,
  ) async throws {
    try "local\n".write(
      to: checkout.appendingPathComponent(name),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await fixture.runner.run(["add", name], in: checkout)
    _ = try await fixture.runner.run(["commit", "-q", "-m", "local"], in: checkout)
  }

  private func stashAChange(in checkout: URL, with fixture: RepositoryFixture) async throws {
    let tracked = try await fixture.runner.run(["ls-files", "-z"], in: checkout)
      .split(separator: "\0").first { $0 != ".gitmodules" }
    let file = checkout.appendingPathComponent(String(try #require(tracked)))
    try "changed\n".write(to: file, atomically: true, encoding: .utf8)
    _ = try await fixture.runner.run(["stash", "push", "-q"], in: checkout)
  }
}
