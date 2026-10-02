import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

/// A project's hooks as the coordinator runs them, against real git.
@Suite(.serialized)
struct WorktreeHooksTests {
  /// The shell may print the physical `/private/var` form of the temp
  /// directory, where Foundation says `/var`.
  private func physicalPath(printed text: String) -> String? {
    Scratch.physicalPath(
      of: URL(fileURLWithPath: text.trimmingCharacters(in: .whitespacesAndNewlines)))
  }

  @Test func hooksReceiveTheDocumentedEnvironment() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      postCreateHook:
        "printf \"%s|%s|%s|%s\" \"$MULTISHELL_PROJECT_PATH\" \"$MULTISHELL_PROJECT_NAME\" \"$MULTISHELL_WORKTREE_PATH\" \"$MULTISHELL_BRANCH\" > env.txt"
    )
    let coordinator = fixture.coordinator
    let path = try await coordinator.createThenRunPostCreate(
      branch: "hooked", in: project, settings: fixture.worktreeSettings)

    let recorded = try String(contentsOf: path.appendingPathComponent("env.txt"), encoding: .utf8)
      .split(separator: "|").map(String.init)
    #expect(recorded[0] == project.path.path)
    #expect(recorded[1] == "demo")
    #expect(recorded[2] == path.path)
    #expect(recorded[3] == "hooked")
  }

  @Test func thePostDeleteHookRunsInTheRepositoryWithTheOldPath() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      postDeleteHook: "printf \"%s|%s\" \"$PWD\" \"$MULTISHELL_WORKTREE_PATH\" > deleted.txt")
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "bye", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "bye", in: project)

    try await fixture.coordinator.removeUnlinking(worktree, in: project)

    let recorded = try String(
      contentsOf: project.path.appendingPathComponent("deleted.txt"), encoding: .utf8
    )
    .split(separator: "|").map(String.init)
    #expect(URL(fileURLWithPath: recorded[0]).standardizedFileURL.lastPathComponent == "demo")
    #expect(recorded[1] == path.path)
  }

  @Test func aHookPastTheTimeoutIsStoppedAndFailsWithTheReason() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(preCreateHook: "echo starting\nsleep 30")
    let started = ContinuousClock.now

    // At half a second a loaded machine killed the login shell during its rc files, and the
    // message was rc noise with nothing of the hook's in it.
    let timeout = Duration.seconds(3)
    do {
      try await fixture.coordinator.createThenRunPostCreate(
        branch: "slow", in: project, settings: fixture.worktreeSettings, timeout: timeout)
      Issue.record("the hook was not stopped")
    } catch let failure as HookFailure {
      #expect(failure.stage == .preCreate)
      #expect(failure.stop == .timedOut(after: timeout))
      #expect((failure.underlying as? ProcessFailure)?.message == "starting")
    }
    #expect(ContinuousClock.now - started < .seconds(10))
    #expect(try await fixture.coordinator.git.list(project).count == 1, "nothing was created")
  }

  @Test func theStopperEndsAPostCreateHookAndTheFailureSaysTheUserAsked() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(postCreateHook: "sleep 30")
    let stopper = ProcessStopper()
    Task {
      try? await Task.sleep(for: .milliseconds(300))
      stopper.stop()
    }

    do {
      try await fixture.coordinator.createThenRunPostCreate(
        branch: "stopped", in: project, settings: fixture.worktreeSettings, stopper: stopper)
      Issue.record("the hook was not stopped")
    } catch let failure as HookFailure {
      #expect(failure.stage == .postCreate && failure.stop == .byUser)
    }
    #expect(try await fixture.coordinator.git.list(project).count == 2, "the worktree exists")
  }

  @Test func aFailingHookLeavesTheWorktreeInPlace() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    var project = fixture.project
    project.settings = ProjectSettings(postCreateHook: "exit 3")
    let settings = fixture.worktreeSettings

    let coordinator = fixture.coordinator
    await #expect(throws: HookFailure.self) {
      try await coordinator.createThenRunPostCreate(
        branch: "doomed", in: project, settings: settings)
    }
    #expect(try await coordinator.git.list(project).contains { $0.branch == "doomed" })
  }

  @Test func aFailingPreCreateHookLeavesNoWorktreeAndNoBranch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(preCreateHook: "echo refused >&2\nexit 7")

    await #expect(throws: HookFailure.self) {
      try await fixture.coordinator.createThenRunPostCreate(
        branch: "refused", in: project, settings: fixture.worktreeSettings)
    }

    #expect(try await fixture.coordinator.git.list(project).count == 1)
    #expect(try await fixture.branches() == ["main"], "git was never asked")
    #expect(
      !FileManager.default.fileExists(
        atPath: fixture.worktreeSettings.worktreePath(forBranch: "refused", in: project).path))
  }

  @Test func aPreCreateHookRunsInTheRepositoryWithThePlannedPath() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      preCreateHook: "pwd > pre.txt\nprintf '%s' \"$MULTISHELL_WORKTREE_PATH\" > planned.txt")

    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "planned", in: project, settings: fixture.worktreeSettings)

    let ran = try String(
      contentsOf: project.path.appendingPathComponent("pre.txt"), encoding: .utf8)
    #expect(
      ran.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/demo"),
      "ran in the repository, not the planned worktree: \(ran)")
    let planned = try String(
      contentsOf: project.path.appendingPathComponent("planned.txt"), encoding: .utf8)
    #expect(planned == path.path, "the path the worktree is about to get")
  }

  @Test func aFailingPreDeleteHookLeavesTheWorktree() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(preDeleteHook: "exit 1")
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "kept", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "kept", in: project)

    await #expect(throws: HookFailure.self) {
      try await fixture.coordinator.removeUnlinking(worktree, in: project)
    }

    #expect(FileManager.default.fileExists(atPath: path.path))
    #expect(try await fixture.coordinator.git.list(project).count == 2)
  }

  @Test func aPreDeleteHookRunsInTheWorktreeBeforeItGoes() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      preDeleteHook: "pwd > \"$MULTISHELL_PROJECT_PATH/where.txt\"")
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "leaving", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "leaving", in: project)

    try await fixture.coordinator.removeUnlinking(worktree, in: project)

    let ran = try String(
      contentsOf: project.path.appendingPathComponent("where.txt"), encoding: .utf8)
    #expect(physicalPath(printed: ran) == Scratch.physicalPath(of: path))
    #expect(!FileManager.default.fileExists(atPath: path.path))
  }

  @Test func aPreDeleteHookRunsInTheRepositoryWhenTheDirectoryIsAlreadyGone() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(preDeleteHook: "pwd > where.txt")
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "vanished", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "vanished", in: project)
    try FileManager.default.removeItem(at: path)

    try await fixture.coordinator.removeUnlinking(worktree, in: project)

    let ran = try String(
      contentsOf: project.path.appendingPathComponent("where.txt"), encoding: .utf8)
    #expect(physicalPath(printed: ran) == Scratch.physicalPath(of: project.path))
    #expect(try await fixture.coordinator.git.list(project).count == 1)
  }

  @Test func aMultiLineHookRunsItsLinesInOrderAndStopsAtAFailure() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      postCreateHook: "echo one >> order.txt\necho two >> order.txt\nfalse\necho three >> order.txt"
    )

    await #expect(throws: HookFailure.self) {
      try await fixture.coordinator.createThenRunPostCreate(
        branch: "lines", in: project, settings: fixture.worktreeSettings)
    }

    let path = fixture.worktreeSettings.worktreePath(forBranch: "lines", in: project)
    let order = try String(contentsOf: path.appendingPathComponent("order.txt"), encoding: .utf8)
    #expect(order == "one\ntwo\n", "in order, in the worktree, and nothing after the failure")
  }

  @Test func hooksRunThroughTheShellTheProjectChose() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let shells = try Scratch.directory("shells")
    defer { Scratch.remove(shells) }
    var project = fixture.project
    project.settings = ProjectSettings(postCreateHook: "true")

    for name in ["zsh", "bash"] {
      let shell = try Scratch.script(
        "printf %s \(name) > shell.txt", at: shells.appendingPathComponent(name))
      let created = try await fixture.coordinator.createThenRunPostCreate(
        branch: name, in: project, settings: fixture.worktreeSettings, shellPath: shell.path)
      #expect(
        try String(contentsOf: created.appendingPathComponent("shell.txt"), encoding: .utf8)
          == name)
    }
  }
}
