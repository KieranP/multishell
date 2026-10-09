import Foundation
import MultishellProcess
import TestScratch
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeCoordinatorStoppedAddTests {
  /// Git makes the worktree, then the add hangs until it is stopped.
  private static let addThenHang = """
    if [ "$1 $2" = "worktree add" ]; then
      git "$@" || exit
      touch "$SCRATCH/added"
      exec sleep 30
    fi
    exec git "$@"
    """

  @Test func aCancelledCreateTakesBackTheBranchAndDirectoriesItMade() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit(
      "slow",
      files: [".gitattributes": "*.dat filter=slow\n", "a.dat": "x\n"],
    )
    _ = try await fixture.runner.run(
      ["config", "filter.slow.smudge", "sleep 30; cat"],
      in: fixture.project.path,
    )
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")
    let stopper = ProcessStopper()
    let coordinator = fixture.coordinator
    let project = fixture.project
    let add = Task {
      try await coordinator.create(
        branch: "held",
        in: project,
        settings: settings,
        stopper: stopper,
      )
    }
    let record = project.path.appendingPathComponent(".git/worktrees/held")
    try await waitUntil { FileManager.default.fileExists(atPath: record.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await fixture.branches() == ["main"])
    #expect(
      !FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("deep").path)
    )
    _ = try await fixture.runner.run(
      ["config", "--unset", "filter.slow.smudge"],
      in: project.path,
    )
    try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "held",
      in: project,
      settings: settings,
    )
  }

  /// The add exits just past a second boundary, so the index wait after it
  /// lasts about a second rather than anything down to 10 ms.
  @Test func aCancelWhileTheNewIndexSettlesTakesBackTheWorktreeAndItsBranch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let fake = try FakeGit.make(
      """
      if [ "$1 $2" = "worktree add" ]; then
        git "$@" || exit
        perl -MTime::HiRes=time,sleep -e 'sleep(1.02 - (time - int(time)))'
        touch "$SCRATCH/added"
        exit 0
      fi
      exec git "$@"
      """
    )
    defer { fake.tearDown() }
    let coordinator = WorktreeCoordinator(git: WorktreeGit(runner: fake.runner))
    let stopper = ProcessStopper()
    let project = fixture.project
    let settings = fixture.worktreeSettings
    let add = Task {
      try await coordinator.create(
        branch: "held",
        in: project,
        settings: settings,
        stopper: stopper,
      )
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    let failure = await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(failure?.stopReason == .byUser)
    #expect(try await fixture.coordinator.git.list(project).map(\.branch) == ["main"])
    #expect(try await fixture.branches() == ["main"])
  }

  @Test func aCreateStoppedAfterGitMadeTheWorktreeTakesItBack() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let fake = try FakeGit.make(Self.addThenHang)
    defer { fake.tearDown() }
    let coordinator = fake.coordinator
    let stopper = ProcessStopper()
    let project = fixture.project
    let settings = fixture.worktreeSettings
    let add = Task {
      try await coordinator.create(
        branch: "held",
        in: project,
        settings: settings,
        stopper: stopper,
      )
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await fixture.coordinator.git.list(project).map(\.branch) == ["main"])
    #expect(try await fixture.branches() == ["main"])
  }

  @Test func aCreateStoppedAfterGitFilledAnEmptyDirectoryAtItsPathTakesItBack() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let fake = try FakeGit.make(Self.addThenHang)
    defer { fake.tearDown() }
    let coordinator = fake.coordinator
    let project = fixture.project
    let settings = fixture.worktreeSettings
    try FileManager.default.createDirectory(
      at: coordinator.plannedPath(forBranch: "held", in: project, settings: settings),
      withIntermediateDirectories: true,
    )
    let stopper = ProcessStopper()
    let add = Task {
      try await coordinator.create(
        branch: "held",
        in: project,
        settings: settings,
        stopper: stopper,
      )
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await fixture.coordinator.git.list(project).map(\.branch) == ["main"])
    #expect(try await fixture.branches() == ["main"])
  }

  @Test func aStoppedCreateLeavesAWorktreeAlreadyRegisteredAtItsPath() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let away = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "away",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)
    _ = try await fixture.runner.run(
      ["branch", "-m", "away", "renamed"],
      in: fixture.project.path,
    )
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await fixture.coordinator.create(
        branch: "away",
        in: fixture.project,
        settings: fixture.worktreeSettings,
        stopper: stopper,
      )
    }

    let listed = try await fixture.coordinator.git.list(fixture.project)
    #expect(listed.map(\.branch) == ["main", "renamed"])
  }

  @Test func aCreateStoppedBeforeGitRanLeavesABranchThatWasAlreadyThere() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commitOnBranch("mywork", file: "mine.txt", content: "x\n", message: "mine")
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await fixture.coordinator.create(
        branch: "mywork",
        in: fixture.project,
        settings: fixture.worktreeSettings,
        stopper: stopper,
      )
    }

    #expect(try await fixture.branches().contains("mywork"))
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
      """
    )
    defer { fake.tearDown() }
    let coordinator = fake.coordinator
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await coordinator.create(
        branch: "mywork",
        in: Project(path: fake.directory),
        settings: WorktreeSettings(worktreeDirectory: "../trees"),
        stopper: stopper,
      )
    }

    #expect(
      !FileManager.default.fileExists(atPath: fake.directory.appendingPathComponent("deleted").path)
    )
  }
}
