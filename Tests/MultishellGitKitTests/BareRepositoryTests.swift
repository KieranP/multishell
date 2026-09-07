import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellGitKit

/// A bare clone with its worktrees beside it, against real git.
@Suite(.serialized)
struct BareRepositoryTests {
  @Test func aBareRepositoryIsARepositoryAndIsTheProjectsRoot() async throws {
    let (repo, checkout) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }

    #expect(await repo.coordinator.isRepository(repo.project.path))
    #expect(await repo.coordinator.isRepository(checkout))
    #expect(await repo.coordinator.isRepository(repo.root) == false)
    #expect(try await repo.coordinator.repositoryRoot(containing: checkout) == repo.project.path)
    #expect(repo.project.name == "repo")
  }

  @Test func theListLeadsWithTheBareEntryWhichGetsNoStatus() async throws {
    let (repo, _) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }

    let listed = try await repo.coordinator.refresh(repo.project)
    #expect(listed.map(\.isBare) == [true, false])
    #expect(listed[0].isPrimary && listed[0].name == "repo.git")
    #expect(listed[1].branch == "main")

    let statuses = await repo.coordinator.statuses(of: listed)
    #expect(statuses.keys.sorted() == [listed[1].id], "git status has no work tree to read there")
  }

  @Test func worktreesAreCreatedAndRemovedFromTheBareRepository() async throws {
    let (repo, _) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }
    #expect(await repo.coordinator.hasCommits(repo.project))
    #expect(try await repo.coordinator.currentBranch(repo.project) == "main")

    let path = try await repo.coordinator.create(
      branch: "feat", in: repo.project, settings: repo.trees)
    #expect(path.path.hasSuffix("/trees/feat"))
    let created = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "feat" })
    try await repo.coordinator.remove(created, deletingBranch: true, in: repo.project)
    #expect(try await repo.coordinator.refresh(repo.project).count == 2)
    #expect(try await repo.branches() == ["main"])
  }

  @Test func theCommonDirectoryIsTheBareRepositoryItself() async throws {
    let (repo, _) = try await RepositoryFixture.makeBare()
    defer { repo.tearDown() }
    let common = try await repo.coordinator.commonGitDirectory(repo.project)
    #expect(common.standardizedFileURL.path == repo.project.path.path)
    #expect(
      WorktreeCoordinator.directoriesToWatch(in: common).map(\.lastPathComponent).sorted()
        == ["main", "worktrees"])
  }
}

/// Removal through the Trash, and the hook timeout and stop, against real
/// git.
@Suite(.serialized)
struct RemovalDisposalTests {
  @Test func aTrashedWorktreeIsHandedOverThenPrunedAndTheHooksStillRun() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let path = try await repo.coordinator.create(branch: "dirty", in: project, settings: repo.trees)
    try "work\n".write(
      to: path.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)
    let worktree = try #require(
      try await repo.coordinator.refresh(project).first { $0.branch == "dirty" })
    let bin = repo.root.appendingPathComponent("bin", isDirectory: true)
    let steps = RemovalStepLog()

    try await repo.coordinator.remove(
      worktree, in: project,
      trash: { url in
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
      },
      onStep: { steps.add($0) })

    #expect(steps.steps == [.removingWorktree, .postDeleteHook])
    #expect(try await repo.coordinator.refresh(project).count == 1, "pruned")
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/wip.txt").path),
      "the work is where the Trash put it")
    #expect(
      FileManager.default.fileExists(
        atPath: project.path.appendingPathComponent("deleted.txt").path))
    #expect(WorktreeRemovalStep.first(for: project) == .removingWorktree)
  }

  @Test func aTrashThatRefusesLeavesTheWorktreeRegisteredAndInPlace() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "kept", in: repo.project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "kept" })

    await #expect(throws: TrashFailure.self) {
      try await repo.coordinator.remove(
        worktree, in: repo.project, trash: { _ in throw CocoaError(.fileWriteNoPermission) })
    }
    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.refresh(repo.project).count == 2, "nothing was pruned")
  }

  @Test func aHookPastTheTimeoutIsStoppedAndFailsWithTheReason() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(preCreateHook: "echo starting\nsleep 30")
    let started = ContinuousClock.now

    // Long enough that the interactive login shell's rc files finish and
    // `echo starting` runs before the stop: at half a second, a loaded
    // machine killed the shell during its own startup and the message was
    // rc noise with nothing of the hook's in it.
    let timeout = Duration.seconds(3)
    do {
      try await repo.coordinator.create(
        branch: "slow", in: project, settings: repo.trees, timeout: timeout)
      Issue.record("the hook was not stopped")
    } catch let failure as HookFailure {
      #expect(failure.stage == .preCreate)
      #expect(failure.stop == .timedOut(after: timeout))
      #expect((failure.underlying as? ProcessFailure)?.message == "starting")
    }
    #expect(ContinuousClock.now - started < .seconds(10))
    #expect(try await repo.coordinator.refresh(project).count == 1, "nothing was created")
  }

  @Test func theStopperEndsAPostCreateHookAndTheFailureSaysTheUserAsked() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "sleep 30")
    let stopper = ProcessStopper()
    Task {
      try await Task.sleep(for: .milliseconds(300))
      stopper.stop()
    }

    do {
      try await repo.coordinator.create(
        branch: "stopped", in: project, settings: repo.trees, stopper: stopper)
      Issue.record("the hook was not stopped")
    } catch let failure as HookFailure {
      #expect(failure.stage == .postCreate && failure.stop == .stopped)
    }
    #expect(try await repo.coordinator.refresh(project).count == 2, "the worktree exists")
  }
}
