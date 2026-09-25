import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellGitKit

/// The path most likely to lose someone's work if it is wrong.
@Suite(.serialized)
struct WorktreeCreationTests {
  @Test func theCreatedWorktreeIsWhereThePlannedPathSaid() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let planned = repo.coordinator.plannedPath(
      forBranch: "feat/tabs", in: repo.project, settings: repo.trees)
    let created = try await repo.coordinator.create(
      branch: "feat/tabs", in: repo.project, settings: repo.trees)

    #expect(created == planned)
    #expect(created.lastPathComponent == "feat-tabs", "slash becomes one directory")
    #expect(try await repo.branches() == ["feat/tabs", "main"], "the branch keeps its slash")
  }

  @Test func theNewBranchStartsAtTheRequestedBase() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let first = try await repo.head(of: repo.project.path)
    try await repo.commit("second", file: "b.txt", content: "b\n")
    _ = try await repo.git.run(["branch", "release", first], in: repo.project.path)

    let path = try await repo.coordinator.create(
      branch: "hotfix", basedOn: "release", in: repo.project, settings: repo.trees)

    #expect(try await repo.head(of: path) == first)
  }

  @Test func withoutABaseTheNewBranchStartsAtHEAD() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    let path = try await repo.coordinator.create(
      branch: "x", in: repo.project, settings: repo.trees)

    #expect(try await repo.head(of: path) == repo.head(of: repo.project.path))
  }

  @Test func anExistingBranchIsCheckedOutNotRecreated() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "existing"], in: repo.project.path)

    let path = try await repo.coordinator.create(
      branch: "existing", createBranch: false, in: repo.project, settings: repo.trees)

    let onBranch = try await repo.git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "existing")
    #expect(try await repo.branches() == ["existing", "main"])
  }

  @Test func thePrefixIsAppliedAndNeverDoubled() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let a = try await repo.coordinator.create(branch: "one", in: repo.project, settings: settings)
    let b = try await repo.coordinator.create(branch: "k/two", in: repo.project, settings: settings)

    #expect(a.lastPathComponent == "k-one")
    #expect(b.lastPathComponent == "k-two")
    #expect(try await repo.branches() == ["k/one", "k/two", "main"])
  }

  @Test func thePrefixIsNotAppliedToAnExistingBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "release"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../trees", branchPrefix: "k/")

    let planned = repo.coordinator.plannedPath(
      forBranch: "release", createBranch: false, in: repo.project, settings: settings)
    let path = try await repo.coordinator.create(
      branch: "release", createBranch: false, in: repo.project, settings: settings)

    #expect(path == planned)
    #expect(path.lastPathComponent == "release", "no k- in the directory either")
    let onBranch = try await repo.git.run(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
    #expect(onBranch.trimmingCharacters(in: .whitespacesAndNewlines) == "release")
    #expect(try await repo.branches() == ["main", "release"], "nothing was created")
  }

  @Test func nestedContainersAreCreatedOnDemand() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    let path = try await repo.coordinator.create(branch: "n", in: repo.project, settings: settings)

    #expect(path.path.hasSuffix("/deep/er/trees/n"))
    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("README.md").path))
  }

  @Test func aRefusedCreateLeavesNoContainerDirectory() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "taken"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.create(branch: "taken", in: repo.project, settings: settings)
    }

    let deep = repo.root.appendingPathComponent("deep", isDirectory: true)
    #expect(
      !FileManager.default.fileExists(atPath: deep.path), "git made nothing, so nothing is left")
  }

  @Test func aCancelledCreateTakesBackTheBranchAndDirectoriesItMade() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    try await repo.commit("slow", files: [".gitattributes": "*.dat filter=slow\n", "a.dat": "x\n"])
    _ = try await repo.git.run(
      ["config", "filter.slow.smudge", "sleep 30; cat"], in: repo.project.path)
    let settings = WorktreeSettings(worktreeDirectory: "../deep/er/trees")
    let stopper = ProcessStopper()
    let coordinator = repo.coordinator
    let project = repo.project
    let add = Task {
      try await coordinator.add(
        branch: "held", in: project, settings: settings, stopper: stopper)
    }
    let record = project.path.appendingPathComponent(".git/worktrees/held")
    try await waitUntil { FileManager.default.fileExists(atPath: record.path) }

    stopper.stop()
    await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(try await repo.branches() == ["main"])
    #expect(!FileManager.default.fileExists(atPath: repo.root.appendingPathComponent("deep").path))
    _ = try await repo.git.run(["config", "--unset", "filter.slow.smudge"], in: project.path)
    try await repo.coordinator.create(branch: "held", in: project, settings: settings)
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
    let settings = repo.trees
    let add = Task {
      try await coordinator.add(branch: "held", in: project, settings: settings, stopper: stopper)
    }
    let added = fake.directory.appendingPathComponent("added")
    try await waitUntil { FileManager.default.fileExists(atPath: added.path) }

    stopper.stop()
    let failure = await #expect(throws: ProcessFailure.self) { try await add.value }

    #expect(failure?.stop == .stopped)
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
    let settings = repo.trees
    let add = Task {
      try await coordinator.add(branch: "held", in: project, settings: settings, stopper: stopper)
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
    let settings = repo.trees
    try FileManager.default.createDirectory(
      at: coordinator.plannedPath(forBranch: "held", in: project, settings: settings),
      withIntermediateDirectories: true)
    let stopper = ProcessStopper()
    let add = Task {
      try await coordinator.add(branch: "held", in: project, settings: settings, stopper: stopper)
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
    let away = try await repo.coordinator.create(
      branch: "away", in: repo.project, settings: repo.trees)
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)
    _ = try await repo.git.run(["branch", "-m", "away", "renamed"], in: repo.project.path)
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await repo.coordinator.add(
        branch: "away", in: repo.project, settings: repo.trees, stopper: stopper)
    }

    let listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.branch) == ["main", "renamed"])
  }

  @Test func aCreateStoppedBeforeGitRanLeavesABranchThatWasAlreadyThere() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["checkout", "-q", "-b", "mywork"], in: repo.project.path)
    try await repo.commit("mine", file: "mine.txt", content: "x\n")
    _ = try await repo.git.run(["checkout", "-q", "main"], in: repo.project.path)
    let stopper = ProcessStopper()
    stopper.stop()

    await #expect(throws: (any Error).self) {
      try await repo.coordinator.add(
        branch: "mywork", in: repo.project, settings: repo.trees, stopper: stopper)
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
      try await coordinator.add(
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

    let settling = WorktreeCoordinator(git: WorktreeGit(runner: repo.git))
    let path = try await settling.create(branch: "fresh", in: repo.project, settings: repo.trees)

    let index = try await repo.git.run(
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
    _ = try await repo.git.run(["branch", "taken"], in: repo.project.path)

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.create(branch: "taken", in: repo.project, settings: repo.trees)
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
    let target = repo.trees.worktreePath(forBranch: "busy", in: project)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try "x".write(to: target.appendingPathComponent("file"), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await repo.coordinator.create(branch: "busy", in: project, settings: repo.trees)
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
        try await repo.coordinator.create(
          branch: name, createBranch: false, in: project, settings: repo.trees)
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
      try await repo.coordinator.create(
        branch: "main", createBranch: false, in: repo.project, settings: repo.trees)
    }
  }

  @Test func removingKeepsTheBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    try await repo.coordinator.create(branch: "keep", in: repo.project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(repo.project).first { $0.branch == "keep" })

    try await repo.coordinator.remove(worktree, in: repo.project)

    #expect(try await repo.branches() == ["keep", "main"])
    #expect(!FileManager.default.fileExists(atPath: worktree.path.path))
  }

  @Test func aDirtyWorktreeIsHandedToTheTrashNotRefused() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "dirty", in: repo.project, settings: repo.trees)
    try "uncommitted\n".write(
      to: path.appendingPathComponent("work.txt"), atomically: true, encoding: .utf8)
    let worktree = try #require(
      try await repo.coordinator.git.list(repo.project).first { $0.branch == "dirty" })
    let bin = repo.root.appendingPathComponent("bin", isDirectory: true)

    try await repo.coordinator.remove(
      worktree, in: repo.project,
      trash: { url in
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: bin.appendingPathComponent("dirty"))
      })

    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(
      FileManager.default.fileExists(atPath: bin.appendingPathComponent("dirty/work.txt").path))
    #expect(try await repo.coordinator.git.list(repo.project).count == 1)
  }

  @Test func theListReflectsCreateAndRemove() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }

    try await repo.coordinator.create(branch: "a", in: repo.project, settings: repo.trees)
    try await repo.coordinator.create(branch: "b", in: repo.project, settings: repo.trees)
    var listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.branch) == ["main", "a", "b"])
    #expect(listed[0].isPrimary && !listed[1].isPrimary)
    #expect(listed.allSatisfy { $0.projectID == repo.project.id })

    try await repo.coordinator.remove(listed[1], in: repo.project)
    listed = try await repo.coordinator.git.list(repo.project)
    #expect(listed.map(\.branch) == ["main", "b"])
  }

  @Test func statusesOmitWorktreesWhoseDirectoryIsGone() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "ghost", in: repo.project, settings: repo.trees)
    let worktrees = try await repo.coordinator.git.list(repo.project)
    try FileManager.default.removeItem(at: path)

    let statuses = await repo.coordinator.readStatuses(of: worktrees).mapValues(\.status)

    #expect(statuses.keys.sorted() == [repo.project.id])
  }

  @Test func thePostDeleteHookRunsInTheRepositoryWithTheOldPath() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postDeleteHook: "printf \"%s|%s\" \"$PWD\" \"$MULTISHELL_WORKTREE_PATH\" > deleted.txt")
    let path = try await repo.coordinator.create(branch: "bye", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.git.list(project).first { $0.branch == "bye" })

    try await repo.coordinator.remove(worktree, in: project)

    let recorded = try String(
      contentsOf: project.path.appendingPathComponent("deleted.txt"), encoding: .utf8
    )
    .split(separator: "|").map(String.init)
    #expect(URL(fileURLWithPath: recorded[0]).standardizedFileURL.lastPathComponent == "demo")
    #expect(recorded[1] == path.path)
  }
}
