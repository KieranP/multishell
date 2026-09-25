import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellGitKit

/// Removal through the Trash, and the hook timeout and stop, against real
/// git.
@Suite(.serialized)
struct RemovalDisposalTests {
  @Test func aTrashedWorktreeIsHandedOverThenForgottenAndTheHooksStillRun() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(postDeleteHook: "echo gone > deleted.txt")
    let path = try await repo.coordinator.create(branch: "dirty", in: project, settings: repo.trees)
    try "work\n".write(
      to: path.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)
    let worktree = try #require(
      try await repo.coordinator.git.list(project).first { $0.branch == "dirty" })
    let bin = repo.root.appendingPathComponent("bin", isDirectory: true)
    let steps = StepLog<WorktreeRemovalStep>()

    try await repo.coordinator.remove(
      worktree, in: project,
      trash: { url in
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
      },
      onStep: { steps.add($0) })

    #expect(steps.steps == [.removingWorktree, .postDeleteHook])
    #expect(try await repo.coordinator.git.list(project).count == 1, "forgotten")
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
      try await repo.coordinator.git.list(repo.project).first { $0.branch == "kept" })

    await #expect(throws: TrashFailure.self) {
      try await repo.coordinator.remove(
        worktree, in: repo.project, trash: { _ in throw CocoaError(.fileWriteNoPermission) })
    }
    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.git.list(repo.project).count == 2, "nothing was pruned")
  }

  @Test func aHookPastTheTimeoutIsStoppedAndFailsWithTheReason() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(preCreateHook: "echo starting\nsleep 30")
    let started = ContinuousClock.now

    // At half a second a loaded machine killed the login shell during its rc files, and the
    // message was rc noise with nothing of the hook's in it.
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
    #expect(try await repo.coordinator.git.list(project).count == 1, "nothing was created")
  }

  @Test func theStopperEndsAPostCreateHookAndTheFailureSaysTheUserAsked() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "sleep 30")
    let stopper = ProcessStopper()
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      stopper.stop()
    }

    do {
      try await repo.coordinator.create(
        branch: "stopped", in: project, settings: repo.trees, stopper: stopper)
      Issue.record("the hook was not stopped")
    } catch let failure as HookFailure {
      #expect(failure.stage == .postCreate && failure.stop == .stopped)
    }
    #expect(try await repo.coordinator.git.list(project).count == 2, "the worktree exists")
  }
}
