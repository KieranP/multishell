import Foundation
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorStoppedAddTests {
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
}
