import Foundation
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

/// The path most likely to lose someone's work if it is wrong.
@Suite(.serialized)
struct WorktreeCoordinatorCreationTests {
  @Test func theCreatedWorktreeIsWhereThePlannedPathSaid() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let planned = repo.coordinator.plannedPath(
      forBranch: "feat/tabs", in: repo.project, settings: repo.worktreeSettings)
    let created = try await repo.coordinator.createThenRunPostCreate(
      branch: "feat/tabs", in: repo.project, settings: repo.worktreeSettings)

    #expect(created == planned)
    #expect(created.lastPathComponent == "feat-tabs", "slash becomes one directory")
    #expect(try await repo.branches() == ["feat/tabs", "main"], "the branch keeps its slash")
  }

  @Test func theNewBranchStartsAtTheRequestedBase() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let first = try await repo.head(of: repo.project.path)
    try await repo.commit("second", file: "b.txt", content: "b\n")
    _ = try await repo.runner.run(["branch", "release", first], in: repo.project.path)

    let path = try await repo.coordinator.createThenRunPostCreate(
      branch: "hotfix", basedOn: "release", in: repo.project, settings: repo.worktreeSettings)

    #expect(try await repo.head(of: path) == first)
  }

  @Test func withoutABaseTheNewBranchStartsAtHEAD() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let path = try await repo.coordinator.createThenRunPostCreate(
      branch: "x", in: repo.project, settings: repo.worktreeSettings)

    #expect(try await repo.head(of: path) == repo.head(of: repo.project.path))
  }

  @Test func anExistingBranchIsCheckedOutNotRecreated() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.runner.run(["branch", "existing"], in: repo.project.path)

    let path = try await repo.coordinator.createThenRunPostCreate(
      branch: "existing", createBranch: false, in: repo.project, settings: repo.worktreeSettings)

    let onBranch = try await repo.runner.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "existing")
    #expect(try await repo.branches() == ["existing", "main"])
  }

  @Test func thePrefixIsAppliedAndNeverDoubled() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let a = try await repo.coordinator.createThenRunPostCreate(
      branch: "one", in: repo.project, settings: settings)
    let b = try await repo.coordinator.createThenRunPostCreate(
      branch: "k/two", in: repo.project, settings: settings)

    #expect(a.lastPathComponent == "k-one")
    #expect(b.lastPathComponent == "k-two")
    #expect(try await repo.branches() == ["k/one", "k/two", "main"])
  }

  @Test func thePrefixIsNotAppliedToAnExistingBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.runner.run(["branch", "release"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let planned = repo.coordinator.plannedPath(
      forBranch: "release", createBranch: false, in: repo.project, settings: settings)
    let path = try await repo.coordinator.createThenRunPostCreate(
      branch: "release", createBranch: false, in: repo.project, settings: settings)

    #expect(path == planned)
    #expect(path.lastPathComponent == "release", "no k- in the directory either")
    let onBranch = try await repo.runner.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "release")
    #expect(try await repo.branches() == ["main", "release"], "nothing was created")
  }

  @Test func nestedContainersAreCreatedOnDemand() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    let path = try await repo.coordinator.createThenRunPostCreate(
      branch: "n", in: repo.project, settings: settings)

    #expect(path.path.hasSuffix("/deep/er/trees/n"))
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("README.md").path))
  }

  @Test func aRefusedCreateLeavesNoContainerDirectory() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.runner.run(["branch", "taken"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.createThenRunPostCreate(
        branch: "taken", in: repo.project, settings: settings)
    }

    let deep = repo.root.appendingPathComponent("deep", isDirectory: true)
    #expect(
      !FileManager.default.fileExists(atPath: deep.path), "git made nothing, so nothing is left")
  }

  @Test func aCancelledCreateTakesBackTheBranchAndDirectoriesItMade() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    try await repo.commit("slow", files: [".gitattributes": "*.dat filter=slow\n", "a.dat": "x\n"])
    _ = try await repo.runner.run(
      ["config", "filter.slow.smudge", "sleep 30; cat"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")
    let stopper = ProcessStopper()
    let coordinator = repo.coordinator
    let project = repo.project
    let add = Task {
      try await coordinator.create(
        branch: "held", in: project, settings: settings, stopper: stopper)
    }
    let record = project.path.appendingPathComponent(".git/worktrees/held")
    try await waitUntil { FileManager.default.fileExists(atPath: record.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await repo.branches() == ["main"])
    #expect(!FileManager.default.fileExists(atPath: repo.root.appendingPathComponent("deep").path))
    _ = try await repo.runner.run(["config", "--unset", "filter.slow.smudge"], in: project.path)
    try await repo.coordinator.createThenRunPostCreate(
      branch: "held", in: project, settings: settings)
  }

  /// The add exits just past a second boundary, so the index wait after it
  /// lasts about a second rather than anything down to 10 ms.
  @Test func aCancelWhileTheNewIndexSettlesTakesBackTheWorktreeAndItsBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let fake = try FakeGit.make(
      """
      if [ "$1 $2" = "worktree add" ]; then
        git "$@" || exit
        perl -MTime::HiRes=time,sleep -e 'sleep(1.02 - (time - int(time)))'
        touch "$SCRATCH/added"
        exit 0
      fi
      exec git "$@"
      """)
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(git: WorktreeGit(runner: fake.runner))
    let stopper = ProcessStopper()
    let project = repo.project
    let settings = repo.worktreeSettings
    let add = Task {
      try await coordinator.create(
        branch: "held", in: project, settings: settings, stopper: stopper)
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    let failure = await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(failure?.stop == .byUser)
    #expect(try await repo.coordinator.git.list(project).map(\.branch) == ["main"])
    #expect(try await repo.branches() == ["main"])
  }

  @Test func aCreateStoppedAfterGitMadeTheWorktreeTakesItBack() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let fake = try FakeGit.make(
      """
      if [ "$1 $2" = "worktree add" ]; then
        git "$@" || exit
        touch "$SCRATCH/added"
        exec sleep 30
      fi
      exec git "$@"
      """)
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(
      git: WorktreeGit(runner: fake.runner, settlesNewIndex: false))
    let stopper = ProcessStopper()
    let project = repo.project
    let settings = repo.worktreeSettings
    let add = Task {
      try await coordinator.create(
        branch: "held", in: project, settings: settings, stopper: stopper)
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await repo.coordinator.git.list(project).map(\.branch) == ["main"])
    #expect(try await repo.branches() == ["main"])
  }

  @Test func aCreateStoppedAfterGitFilledAnEmptyDirectoryAtItsPathTakesItBack() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let fake = try FakeGit.make(
      """
      if [ "$1 $2" = "worktree add" ]; then
        git "$@" || exit
        touch "$SCRATCH/added"
        exec sleep 30
      fi
      exec git "$@"
      """)
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(
      git: WorktreeGit(runner: fake.runner, settlesNewIndex: false))
    let project = repo.project
    let settings = repo.worktreeSettings
    try FileManager.default.createDirectory(
      at: coordinator.plannedPath(forBranch: "held", in: project, settings: settings),
      withIntermediateDirectories: true)
    let stopper = ProcessStopper()
    let add = Task {
      try await coordinator.create(
        branch: "held", in: project, settings: settings, stopper: stopper)
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await repo.coordinator.git.list(project).map(\.branch) == ["main"])
    #expect(try await repo.branches() == ["main"])
  }

  @Test func aStoppedCreateLeavesAWorktreeAlreadyRegisteredAtItsPath() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let away = try await repo.coordinator.createThenRunPostCreate(
      branch: "away", in: repo.project, settings: repo.worktreeSettings)
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)
    _ = try await repo.runner.run(["branch", "-m", "away", "renamed"], in: repo.project.path)
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await repo.coordinator.create(
        branch: "away", in: repo.project, settings: repo.worktreeSettings, stopper: stopper)
    }

    let listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.branch) == ["main", "renamed"])
  }

  @Test func aCreateStoppedBeforeGitRanLeavesABranchThatWasAlreadyThere() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.runner.run(["checkout", "-q", "-b", "mywork"], in: repo.project.path)
    try await repo.commit("mine", file: "mine.txt", content: "x\n")
    _ = try await repo.runner.run(["checkout", "-q", "main"], in: repo.project.path)
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await repo.coordinator.create(
        branch: "mywork", in: repo.project, settings: repo.worktreeSettings, stopper: stopper)
    }

    #expect(try await repo.branches().contains("mywork"))
  }

  @Test func aStoppedCreateWhoseBranchLookupFailedDeletesNoBranch() async throws {
    let fake = try FakeGit.make(
      """
      case "$1 $2" in
        "rev-parse --verify") exit 128 ;;
        "worktree add") exit 128 ;;
        "worktree list") printf 'worktree %s\\0HEAD a\\0branch refs/heads/main\\0\\0' "$SCRATCH" ;;
        "branch -D") echo "$3" >> "$SCRATCH/deleted" ;;
      esac
      """)
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(
      git: WorktreeGit(runner: fake.runner, settlesNewIndex: false))
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await coordinator.create(
        branch: "mywork", in: Project(path: fake.directory),
        settings: WorktreeSettings(worktreeDirectory: "../trees"), stopper: stopper)
    }

    #expect(
      !FileManager.default.fileExists(atPath: fake.directory.appendingPathComponent("deleted").path)
    )
  }

  @Test func aNewWorktreesIndexIsWrittenAfterTheSecondItsFilesWereCheckedOutIn() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let settling = WorktreeCoordinator(git: WorktreeGit(runner: repo.runner))
    let path = try await settling.createThenRunPostCreate(
      branch: "fresh", in: repo.project, settings: repo.worktreeSettings)

    let index = try await repo.runner.run(
      ["rev-parse", "--path-format=absolute", "--git-path", "index"], in: path
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
    func second(_ file: String) throws -> Int {
      let date = try #require(
        try FileManager.default.attributesOfItem(atPath: file)[.modificationDate] as? Date)
      return Int(date.timeIntervalSince1970.rounded(.down))
    }
    #expect(try second(index) > second(path.appendingPathComponent("README.md").path))
  }

  @Test func aBranchThatAlreadyExistsIsAGitErrorNotACrash() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.runner.run(["branch", "taken"], in: repo.project.path)

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.createThenRunPostCreate(
        branch: "taken", in: repo.project, settings: repo.worktreeSettings)
    }
    #expect(
      try await repo.coordinator.git.list(repo.project).count == 1, "nothing was created")
  }

  @Test func anOccupiedTargetDirectoryIsRefusedAndTheHookDoesNotRun() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postCreateHook: "touch \"$MULTISHELL_PROJECT_PATH/hook-ran\"")
    let target = repo.worktreeSettings.worktreePath(forBranch: "busy", in: project)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try "x".write(to: target.appendingPathComponent("file"), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.createThenRunPostCreate(
        branch: "busy", in: project, settings: repo.worktreeSettings)
    }
    #expect(
      !FileManager.default.fileExists(atPath: project.path.appendingPathComponent("hook-ran").path))
  }

  /// The sheet cannot send these, Create being off for a name not in the
  /// list; an API caller can, and the hook used to run before git refused.
  @Test func anExistingBranchNameGitWillRefuseRunsNoHook() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      preCreateHook: "touch \"$MULTISHELL_PROJECT_PATH/hook-ran\"")
    let marker = project.path.appendingPathComponent("hook-ran")

    for name in ["", "  ", "my branch", "HEAD"] {
      await #expect(throws: InvalidBranchName.self, "\(name.debugDescription)") {
        try await repo.coordinator.createThenRunPostCreate(
          branch: name, createBranch: false, in: project, settings: repo.worktreeSettings)
      }
      #expect(!FileManager.default.fileExists(atPath: marker.path), "the hook did not run")
    }
    #expect(try await repo.coordinator.git.list(project).count == 1, "nothing was created")
  }

  @Test func aBranchCheckedOutElsewhereCannotBeCheckedOutAgain() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    // `main` is checked out in the primary worktree already.
    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.createThenRunPostCreate(
        branch: "main", createBranch: false, in: repo.project, settings: repo.worktreeSettings)
    }
  }

  @Test func aWorktreeLandsWhereTheSettingsSayOnAPrefixedBranchAndThePostCreateHookRunsInIt()
    async throws
  {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    var project = repo.project
    project.settings = ProjectSettings(postCreateHook: "echo created > hook.txt")
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "kieran/")

    let coordinator = repo.coordinator
    let path = try await coordinator.createThenRunPostCreate(
      branch: "tabs", in: project, settings: settings)

    #expect(path.lastPathComponent == "kieran-tabs")
    #expect(path.deletingLastPathComponent().lastPathComponent == "trees")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("hook.txt").path))

    let worktrees = try await coordinator.git.list(project)
    #expect(worktrees.count == 2)
    #expect(worktrees.contains { $0.branch == "kieran/tabs" })
  }

  @Test func creationReportsEachStepAndSkipsHooksWithNoScript() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let steps = StepLog<WorktreeCreationStep>()

    try await repo.coordinator.createThenRunPostCreate(
      branch: "plain", in: repo.project, settings: repo.worktreeSettings, onStep: { steps.add($0) })
    #expect(steps.steps == [.addingWorktree], "no hooks, so no hook steps")

    var hooked = repo.project
    hooked.settings = ProjectSettings(preCreateHook: "true", postCreateHook: "true")
    steps.clear()
    try await repo.coordinator.createThenRunPostCreate(
      branch: "hooked", in: hooked, settings: repo.worktreeSettings, onStep: { steps.add($0) })
    #expect(steps.steps == [.preCreateHook, .addingWorktree])

    var refused = repo.project
    refused.settings = ProjectSettings(preCreateHook: "exit 1", postCreateHook: "true")
    steps.clear()
    await #expect(throws: HookFailure.self) {
      try await repo.coordinator.createThenRunPostCreate(
        branch: "refused", in: refused, settings: repo.worktreeSettings, onStep: { steps.add($0) })
    }
    #expect(steps.steps == [.preCreateHook], "nothing past the veto")
  }

  @Test func createStopsBeforeThePostHookWhichRunPostCreateThenRuns() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      preCreateHook: "echo pre > pre.txt", postCreateHook: "echo post > post.txt")

    let path = try await repo.coordinator.create(
      branch: "halves", in: project, settings: repo.worktreeSettings)

    #expect(
      FileManager.default.fileExists(atPath: project.path.appendingPathComponent("pre.txt").path))
    #expect(try await repo.coordinator.git.list(project).count == 2, "the worktree exists")
    #expect(!FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))

    try await repo.coordinator.runPostCreate(for: project, worktreePath: path, branch: "halves")
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("post.txt").path))
  }
}
