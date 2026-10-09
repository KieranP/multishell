import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorCreationTests {
  @Test func theCreatedWorktreeIsWhereThePlannedPathSaid() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    let planned = fixture.coordinator.plannedPath(
      forBranch: "feat/tabs",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    let created = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "feat/tabs",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )

    #expect(created == planned)
    #expect(created.lastPathComponent == "feat-tabs", "slash becomes one directory")
    #expect(try await fixture.branches() == ["feat/tabs", "main"], "the branch keeps its slash")
  }

  @Test func theNewBranchStartsAtTheRequestedBase() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let first = try await fixture.head(of: fixture.project.path)
    try await fixture.commit("second", file: "b.txt", content: "b\n")
    _ = try await fixture.runner.run(["branch", "release", first], in: fixture.project.path)

    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "hotfix",
      in: fixture.project,
      settings: fixture.worktreeSettings,
      basedOn: "release",
    )

    #expect(try await fixture.head(of: path) == first)
  }

  @Test func withoutABaseTheNewBranchStartsAtHEAD() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "x",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )

    #expect(try await fixture.head(of: path) == fixture.head(of: fixture.project.path))
  }

  @Test func anExistingBranchIsCheckedOutNotRecreated() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "existing"], in: fixture.project.path)

    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "existing",
      in: fixture.project,
      settings: fixture.worktreeSettings,
      createsBranch: false,
    )

    let onBranch = try await fixture.runner.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "existing")
    #expect(try await fixture.branches() == ["existing", "main"])
  }

  @Test func thePrefixIsAppliedAndNeverDoubled() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let one = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "one",
      in: fixture.project,
      settings: settings,
    )
    let two = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "k/two",
      in: fixture.project,
      settings: settings,
    )

    #expect(one.lastPathComponent == "k-one")
    #expect(two.lastPathComponent == "k-two")
    #expect(try await fixture.branches() == ["k/one", "k/two", "main"])
  }

  @Test func thePrefixIsNotAppliedToAnExistingBranch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "release"], in: fixture.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let planned = fixture.coordinator.plannedPath(
      forBranch: "release",
      in: fixture.project,
      settings: settings,
      createsBranch: false,
    )
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "release",
      in: fixture.project,
      settings: settings,
      createsBranch: false,
    )

    #expect(path == planned)
    #expect(path.lastPathComponent == "release", "no k- in the directory either")
    let onBranch = try await fixture.runner.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "release")
    #expect(try await fixture.branches() == ["main", "release"], "nothing was created")
  }

  @Test func nestedContainersAreCreatedOnDemand() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "n",
      in: fixture.project,
      settings: settings,
    )

    #expect(path.path.hasSuffix("/deep/er/trees/n"))
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("README.md").path))
  }

  @Test func aRefusedCreateLeavesNoContainerDirectory() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "taken"], in: fixture.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    await #expect(throws: ProcessFailure.self) {
      try await fixture.coordinator.createThenRunPostCreateHook(
        branch: "taken",
        in: fixture.project,
        settings: settings,
      )
    }

    let deep = fixture.root.appendingPathComponent("deep", isDirectory: true)
    #expect(
      !FileManager.default.fileExists(atPath: deep.path),
      "git made nothing, so nothing is left",
    )
  }

  @Test func aNewWorktreesIndexIsWrittenAfterTheSecondItsFilesWereCheckedOutIn() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    let settling = WorktreeCoordinator(git: WorktreeGit(runner: fixture.runner))
    let path = try await settling.createThenRunPostCreateHook(
      branch: "fresh",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )

    let index = try await fixture.runner.run(
      ["rev-parse", "--path-format=absolute", "--git-path", "index"],
      in: path,
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
    func second(_ file: String) throws -> Int {
      let date = try #require(
        try FileManager.default.attributesOfItem(atPath: file)[.modificationDate] as? Date
      )
      return Int(date.timeIntervalSince1970.rounded(.down))
    }
    #expect(try second(index) > second(path.appendingPathComponent("README.md").path))
  }

  @Test func aBranchThatAlreadyExistsIsAGitErrorNotACrash() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "taken"], in: fixture.project.path)

    await #expect(throws: ProcessFailure.self) {
      try await fixture.coordinator.createThenRunPostCreateHook(
        branch: "taken",
        in: fixture.project,
        settings: fixture.worktreeSettings,
      )
    }
    #expect(
      try await fixture.coordinator.git.list(fixture.project).count == 1,
      "nothing was created",
    )
  }

  @Test func anOccupiedTargetDirectoryIsRefusedAndTheHookDoesNotRun() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      postCreateHook: "touch \"$MULTISHELL_PROJECT_PATH/hook-ran\""
    )
    let target = fixture.worktreeSettings.worktreePath(forBranch: "busy", in: project)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try "x".write(to: target.appendingPathComponent("file"), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await fixture.coordinator.createThenRunPostCreateHook(
        branch: "busy",
        in: project,
        settings: fixture.worktreeSettings,
      )
    }
    #expect(
      !FileManager.default.fileExists(atPath: project.path.appendingPathComponent("hook-ran").path)
    )
  }

  /// The sheet cannot send these, Create being off for a name not in the
  /// list; an API caller can, and the hook used to run before git refused.
  @Test func anExistingBranchNameGitWillRefuseRunsNoHook() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      preCreateHook: "touch \"$MULTISHELL_PROJECT_PATH/hook-ran\""
    )
    let marker = project.path.appendingPathComponent("hook-ran")

    for name in ["", "  ", "my branch", "HEAD"] {
      await #expect(throws: InvalidBranchName.self, "\(name.debugDescription)") {
        try await fixture.coordinator.createThenRunPostCreateHook(
          branch: name,
          in: project,
          settings: fixture.worktreeSettings,
          createsBranch: false,
        )
      }
      #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    }
    #expect(try await fixture.coordinator.git.list(project).count == 1, "nothing was created")
  }

  @Test func aBranchCheckedOutElsewhereCannotBeCheckedOutAgain() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    // `main` is checked out in the primary worktree already.
    await #expect(throws: ProcessFailure.self) {
      try await fixture.coordinator.createThenRunPostCreateHook(
        branch: "main",
        in: fixture.project,
        settings: fixture.worktreeSettings,
        createsBranch: false,
      )
    }
  }

  @Test func aWorktreeLandsWhereTheSettingsSayOnAPrefixedBranchAndThePostCreateHookRunsInIt()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    var project = fixture.project
    project.settings = ProjectSettings(postCreateHook: "echo created > hook.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "kieran/")

    let coordinator = fixture.coordinator
    let path = try await coordinator.createThenRunPostCreateHook(
      branch: "tabs",
      in: project,
      settings: settings,
    )

    #expect(path.lastPathComponent == "kieran-tabs")
    #expect(path.deletingLastPathComponent().lastPathComponent == "trees")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("hook.txt").path))

    let worktrees = try await coordinator.git.list(project)
    #expect(worktrees.count == 2)
    #expect(worktrees.contains { $0.branch == "kieran/tabs" })
  }

  @Test func creationReportsEachStepAndSkipsHooksWithNoScript() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let steps = Recorder<WorktreeCreationStep>()

    try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "plain",
      in: fixture.project,
      settings: fixture.worktreeSettings,
      onStep: { steps.record($0) },
    )
    #expect(steps.received == [.addingWorktree], "no hooks, so no hook steps")

    var hooked = fixture.project
    hooked.settings = ProjectSettings(preCreateHook: "true", postCreateHook: "true")
    steps.clear()
    try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "hooked",
      in: hooked,
      settings: fixture.worktreeSettings,
      onStep: { steps.record($0) },
    )
    #expect(steps.received == [.preCreateHook, .addingWorktree])

    var refused = fixture.project
    refused.settings = ProjectSettings(preCreateHook: "exit 1", postCreateHook: "true")
    steps.clear()
    await #expect(throws: HookFailure.self) {
      try await fixture.coordinator.createThenRunPostCreateHook(
        branch: "refused",
        in: refused,
        settings: fixture.worktreeSettings,
        onStep: { steps.record($0) },
      )
    }
    #expect(steps.received == [.preCreateHook], "nothing past the veto")
  }

  @Test func createStopsBeforeThePostHookWhichRunPostCreateThenRuns() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    project.settings = ProjectSettings(
      preCreateHook: "echo pre > pre.txt",
      postCreateHook: "echo post > post.txt",
    )

    let path = try await fixture.coordinator.create(
      branch: "halves",
      in: project,
      settings: fixture.worktreeSettings,
    )

    #expect(
      FileManager.default.fileExists(atPath: project.path.appendingPathComponent("pre.txt").path)
    )
    #expect(try await fixture.coordinator.git.list(project).count == 2, "the worktree exists")
    #expect(!FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))

    try await fixture.coordinator.runPostCreateHook(
      for: project,
      worktreePath: path,
      branch: "halves",
    )
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))
  }
}
