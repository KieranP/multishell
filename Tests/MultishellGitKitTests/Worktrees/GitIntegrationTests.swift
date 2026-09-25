import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct GitIntegrationTests {
  @Test func hooksReceiveTheDocumentedEnvironment() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    project.settings = ProjectSettings(
      postCreateHook:
        "printf \"%s|%s|%s|%s\" \"$MULTISHELL_PROJECT_PATH\" \"$MULTISHELL_PROJECT_NAME\" \"$MULTISHELL_WORKTREE_PATH\" \"$MULTISHELL_BRANCH\" > env.txt"
    )
    let coordinator = repo.coordinator
    let path = try await coordinator.create(
      branch: "hooked", in: project, settings: WorktreeSettings(worktreeDirectory: "../trees"))

    let recorded = try String(contentsOf: path.appendingPathComponent("env.txt"), encoding: .utf8)
      .split(separator: "|").map(String.init)
    #expect(recorded[0] == project.path.path)
    #expect(recorded[1] == "demo")
    #expect(recorded[2] == path.path)
    #expect(recorded[3] == "hooked")
  }

  @Test func watchPathsMoveFromDotGitToWorktreesOnceOneExists() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let project = repo.project
    let coordinator = repo.coordinator

    // Asked the way the app asks: the common directory once, then the
    // directories read off it without spawning git for each watcher tick.
    let common = try await coordinator.git.commonGitDirectory(project)

    let before = WorktreeRecords.directoriesToWatch(in: common)
    #expect(before.map(\.lastPathComponent) == [".git"])

    try await coordinator.create(
      branch: "one", in: project, settings: WorktreeSettings(worktreeDirectory: "../trees"))
    let after = WorktreeRecords.directoriesToWatch(in: common)
    #expect(after.map(\.lastPathComponent) == ["worktrees", "one"])
  }

  @Test func statusReflectsWorkingTreeChangesAndBranch() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let project = repo.project
    let worktreeGit = WorktreeGit(runner: repo.git)
    let main = try await worktreeGit.list(project)[0]

    #expect(try await worktreeGit.status(of: main).isClean)

    try "changed\n".write(
      to: project.path.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    try "new\n".write(
      to: project.path.appendingPathComponent("scratch.txt"), atomically: true, encoding: .utf8)
    let dirty = try await worktreeGit.status(of: main)

    #expect(dirty.unstaged == 1)
    #expect(dirty.untracked == 1)
    #expect(dirty.changedFiles == 2)
    #expect(dirty.branch == "main")
  }

  @Test func statusCountsLinesAddedAndRemovedAgainstHead() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "counted.txt", content: "a\nb\nc\n")
    let main = try await worktreeGit.list(repo.project)[0]

    let clean = try await worktreeGit.status(of: main)
    #expect(clean.insertions == 0 && clean.deletions == 0)

    try "a\nx\ny\nz\n".write(
      to: repo.project.path.appendingPathComponent("counted.txt"), atomically: true,
      encoding: .utf8)
    try "untracked\n".write(
      to: repo.project.path.appendingPathComponent("loose.txt"), atomically: true, encoding: .utf8)
    let dirty = try await worktreeGit.status(of: main)

    #expect(dirty.insertions == 4)
    #expect(dirty.deletions == 2)
    #expect(dirty.summary.hasPrefix("+4 −2 · "))
  }

  @Test func aModeChangeAndANewBinaryFileCountAsFilesWithNoLines() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    let script = repo.project.path.appendingPathComponent("run.sh")
    try await repo.commit("seed", file: "run.sh", content: "echo hi\n")
    let main = try await worktreeGit.list(repo.project)[0]

    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755], ofItemAtPath: script.path)
    try Data([0x89, 0x50, 0x00, 0x01]).write(
      to: repo.project.path.appendingPathComponent("icon.png"))
    let status = try await worktreeGit.status(of: main)

    #expect(status.insertions == 0 && status.deletions == 0)
    #expect(status.unscoredFiles == 2, "the mode change and the new png")
    #expect(status.summary.contains("2 files with no lines to count"))
  }

  /// `git status` collapses an untracked directory to one entry while
  /// `ls-files --others` lists every file in it; see Docs/design/worktrees.md.
  @Test func anUntrackedDirectoryIsOneEntryWhoseLinesAreStillCounted() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "counted.txt", content: "a\n")
    let main = try await worktreeGit.list(repo.project)[0]
    let fresh = repo.project.path.appendingPathComponent("fresh", isDirectory: true)
    try FileManager.default.createDirectory(at: fresh, withIntermediateDirectories: true)
    try "a\nb\n".write(
      to: fresh.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
    try "c\nd\n".write(
      to: fresh.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)

    let status = try await worktreeGit.status(of: main)

    #expect(status.untracked == 1, "the directory, which is what git reports")
    #expect(status.changedFiles == 1)
    #expect(status.insertions == 4, "both files inside it, read through ls-files")
    #expect(status.unscoredFiles == 0)
  }

  /// An unmerged path prints `0 0` from `--numstat --cached`, which read as
  /// a file with no lines to count; the tooltip already says it is conflicted.
  @Test func aConflictedFileIsNotCountedAsAFileWithNoLines() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "f.txt", content: "a\nb\n")
    _ = try await repo.git.run(["checkout", "-q", "-b", "other"], in: repo.project.path)
    try await repo.commit("theirs", file: "f.txt", content: "x\nb\n")
    _ = try await repo.git.run(["checkout", "-q", "main"], in: repo.project.path)
    try await repo.commit("mine", file: "f.txt", content: "y\nb\n")
    _ = try? await repo.git.run(["merge", "other"], in: repo.project.path)
    let main = try await worktreeGit.list(repo.project)[0]

    let staged = try await worktreeGit.status(of: main, counting: .stagedOnly)

    #expect(staged.conflicted == 1)
    #expect(staged.unscoredFiles == 0, "the conflict is not a binary file or a rename")
  }

  @Test func stagedOnlyCountsTheIndexAndNoUntrackedFile() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let worktreeGit = WorktreeGit(runner: repo.git)
    try await repo.commit("seed", file: "counted.txt", content: "a\nb\nc\n")
    let main = try await worktreeGit.list(repo.project)[0]

    try "a\nx\ny\nz\n".write(
      to: repo.project.path.appendingPathComponent("counted.txt"), atomically: true,
      encoding: .utf8)
    try "untracked\n".write(
      to: repo.project.path.appendingPathComponent("loose.txt"), atomically: true, encoding: .utf8)

    let unstaged = try await worktreeGit.status(of: main, counting: .stagedOnly)
    #expect(unstaged.insertions == 0 && unstaged.deletions == 0 && unstaged.unscoredFiles == 0)

    _ = try await repo.git.run(["add", "counted.txt"], in: repo.project.path)
    let staged = try await worktreeGit.status(of: main, counting: .stagedOnly)
    #expect(staged.insertions == 3)
    #expect(staged.deletions == 2)
  }

  /// git records no creation date, so this is the birth time of the directory that
  /// `git worktree add` made, and the second worktree must not read as the older.
  @Test func listStampsEachWorktreeWithItsDirectorysCreationDate() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let project = repo.project
    let coordinator = repo.coordinator
    let trees = WorktreeSettings(worktreeDirectory: "../trees")
    try await coordinator.create(branch: "first", in: project, settings: trees)
    try await coordinator.create(branch: "second", in: project, settings: trees)

    let listed = try await WorktreeGit(runner: repo.git).list(project)
    let dates = try listed.map { try #require($0.createdAt, "no date for \($0.name)") }
    let byBranch = Dictionary(uniqueKeysWithValues: zip(listed.map(\.name), dates))

    #expect(byBranch["first"]! <= byBranch["second"]!)
    #expect(byBranch["main"]! <= byBranch["first"]!, "the repository predates its worktrees")
  }

  @Test func removingAWorktreeWhoseDirectoryIsGonePrunesIt() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let project = repo.project
    let coordinator = repo.coordinator
    let path = try await coordinator.create(
      branch: "ghost", in: project, settings: WorktreeSettings(worktreeDirectory: "../trees"))
    try FileManager.default.removeItem(at: path)

    let ghost = try #require(
      try await coordinator.git.list(project).first { $0.branch == "ghost" })
    try await coordinator.remove(ghost, in: project)

    #expect(try await coordinator.git.list(project).count == 1)
  }

  /// Both fail: the directory is in the Trash by then, so the caller has to
  /// be able to tell this from a Trash that refused.
  @Test func aRecordNeitherRemoveNorPruneLetsGoOfIsItsOwnFailure() async throws {
    let fake = try FakeGit.make("exit 128")
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)
    let worktree = Worktree(
      path: fake.directory.appendingPathComponent("gone"), projectID: project.id, head: "a",
      branch: "gone")

    await #expect(throws: WorktreeForgetFailure.self) {
      try await WorktreeGit(runner: fake.runner).forget(worktree, in: project)
    }
  }

  /// `prune` exits 0 having removed nothing, so its success cannot stand in
  /// for the record going: `remove` then reports a removal that never was.
  @Test func aPruneThatLeavesTheRecordListedIsStillAFailure() async throws {
    let fake = try FakeGit.make(
      """
      case "$1 $2" in
        "worktree remove") exit 128 ;;
        "worktree prune") exit 0 ;;
        "worktree list") printf 'worktree %s/gone\\0HEAD a\\0branch refs/heads/gone\\0\\0' "$SCRATCH" ;;
      esac
      """)
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)
    let worktree = Worktree(
      path: fake.directory.appendingPathComponent("gone"), projectID: project.id, head: "a",
      branch: "gone")

    await #expect(throws: WorktreeForgetFailure.self) {
      try await WorktreeGit(runner: fake.runner).forget(worktree, in: project)
    }
  }

  /// Every repository has its main worktree, so a list of none is git failing
  /// quietly, which `list` treats the same way.
  @Test func aListOfNoWorktreesAtAllIsNotProofTheRecordWent() async throws {
    let fake = try FakeGit.make(
      """
      case "$1 $2" in
        "worktree remove") exit 128 ;;
      esac
      """)
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)
    let worktree = Worktree(
      path: fake.directory.appendingPathComponent("gone"), projectID: project.id, head: "a",
      branch: "gone")

    await #expect(throws: WorktreeForgetFailure.self) {
      try await WorktreeGit(runner: fake.runner).forget(worktree, in: project)
    }
  }

  @Test func aPruneThatTakesTheRecordIsASuccess() async throws {
    let fake = try FakeGit.make(
      """
      case "$1 $2" in
        "worktree remove") exit 128 ;;
        "worktree prune") exit 0 ;;
        "worktree list") printf 'worktree %s\\0HEAD a\\0branch refs/heads/main\\0\\0' "$SCRATCH" ;;
      esac
      """)
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)
    let worktree = Worktree(
      path: fake.directory.appendingPathComponent("gone"), projectID: project.id, head: "a",
      branch: "gone")

    try await WorktreeGit(runner: fake.runner).forget(worktree, in: project)
  }

  @Test func hasCommitsIsFalseUntilTheFirstCommit() async throws {
    let repo = try await RepositoryFixture.make(commit: false)
    defer { repo.tearDown() }
    let project = repo.project
    let coordinator = repo.coordinator

    #expect(await coordinator.git.hasCommits(project) == false)
    try "x\n".write(to: project.path.appendingPathComponent("f"), atomically: true, encoding: .utf8)
    _ = try await repo.git.run(["add", "."], in: project.path)
    _ = try await repo.git.run(["commit", "-m", "first"], in: project.path)
    #expect(await coordinator.git.hasCommits(project) == true)
  }

  @Test func remoteBranchesComeFromRefsRemotesWithoutHEAD() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let upstream = repo.project
    _ = try await repo.git.run(["branch", "feature"], in: upstream.path)
    let clone = repo.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await repo.git.run(["clone", "-q", upstream.path.path, clone.path], in: repo.root)

    let branches = try await WorktreeGit(runner: repo.git).remoteBranches(Project(path: clone))
    #expect(branches.sorted() == ["origin/feature", "origin/main"])
  }
}
