import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitRemovalTests {
  /// A repository-wide prune after the trash would also forget a worktree
  /// whose drive is unmounted at that moment; see Docs/design/worktrees.md.
  @Test func removingOneWorktreeKeepsAnotherWhoseDirectoryIsAway() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "gone", in: fixture.project, settings: fixture.worktreeSettings)
    let away = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "away", in: fixture.project, settings: fixture.worktreeSettings)
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)
    let gone = try await fixture.worktree(onBranch: "gone")

    try await fixture.coordinator.removeUnlinking(gone, in: fixture.project)

    let listed = try await fixture.coordinator.git.list(fixture.project)
    #expect(listed.map(\.branch) == ["main", "away"], "the away worktree is still on record")
    try FileManager.default.moveItem(at: aside, to: away)
    #expect(
      try await fixture.head(of: away) == fixture.head(of: fixture.project.path), "and works again")
  }

  @Test func removingAStaleRecordKeepsAnotherWorktreeWhoseDirectoryIsAway() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let (stale, path) = try await fixture.worktreeWithItsDirectoryGone()
    let away = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "away", in: fixture.project, settings: fixture.worktreeSettings)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)

    try await fixture.coordinator.removeUnlinking(stale, in: fixture.project)

    let listed = try await fixture.coordinator.git.list(fixture.project)
    #expect(listed.map(\.branch) == ["main", "away"])
    try FileManager.default.moveItem(at: aside, to: away)
    #expect(try await fixture.head(of: away) == fixture.head(of: fixture.project.path))
  }

  @Test func aDirectoryThatTookAStaleRecordsPathIsNotTrashed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let (stale, path) = try await fixture.worktreeWithItsDirectoryGone()
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    let notes = path.appendingPathComponent("notes.txt")
    try "mine\n".write(to: notes, atomically: true, encoding: .utf8)

    try await fixture.coordinator.removeUnlinking(stale, in: fixture.project)

    #expect(FileManager.default.fileExists(atPath: notes.path))
    #expect(try await fixture.coordinator.git.list(fixture.project).map(\.branch) == ["main"])
  }

  @Test func aLockedStaleRecordIsForgottenAndTheDirectoryAtItsPathKept() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let (stale, path) = try await fixture.worktreeWithItsDirectoryGone(lockedFor: "external drive")
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    let notes = path.appendingPathComponent("notes.txt")
    try "mine\n".write(to: notes, atomically: true, encoding: .utf8)

    try await fixture.coordinator.removeUnlinking(stale, in: fixture.project)

    #expect(FileManager.default.fileExists(atPath: notes.path))
    #expect(try await fixture.coordinator.git.list(fixture.project).map(\.branch) == ["main"])
  }

  /// Stands in for a `safe.directory` refusal or a timeout inside the checkout alone.
  @Test func aCheckoutGitCannotReadIsStillRemovedWithItsHooks() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "unread", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "unread", in: project)
    let fake = try FakeGit.make(
      """
      case "$*" in *--show-toplevel*) exit 128 ;; esac
      exec git "$@"
      """)
    defer { fake.tearDown() }
    let ran = fixture.root.appendingPathComponent("pre-ran")
    project.settings = ProjectSettings(preDeleteHook: "touch \"\(ran.path)\"")
    let coordinator = fake.coordinator

    try await coordinator.removeUnlinking(worktree, in: project, shellPath: "/bin/sh")

    #expect(FileManager.default.fileExists(atPath: ran.path))
    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(try await fixture.coordinator.git.list(project).map(\.branch) == ["main"])
  }

  /// git before 2.31 echoes `--path-format=absolute` back as an unknown flag
  /// and prints the common directory relative to where it ran.
  @Test func aCheckoutIsRemovedWithItsHooksOnAGitThatPredatesPathFormat() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    var project = fixture.project
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "older", in: project, settings: fixture.worktreeSettings)
    let worktree = try await fixture.worktree(onBranch: "older", in: project)
    let fake = try FakeGit.make(
      """
      if [ "$1" = rev-parse ]; then
        for arg; do
          shift
          if [ "$arg" = --path-format=absolute ]; then echo "$arg"; else set -- "$@" "$arg"; fi
        done
      fi
      exec git "$@"
      """)
    defer { fake.tearDown() }
    let ran = fixture.root.appendingPathComponent("pre-ran")
    project.settings = ProjectSettings(preDeleteHook: "touch \"\(ran.path)\"")
    let coordinator = fake.coordinator

    let common = try await coordinator.git.commonGitDirectory(project)
    try await coordinator.removeUnlinking(worktree, in: project, shellPath: "/bin/sh")

    #expect(
      common.resolvingSymlinksInPath().path
        == project.path.appendingPathComponent(".git").resolvingSymlinksInPath().path)
    #expect(FileManager.default.fileExists(atPath: ran.path))
    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(try await fixture.coordinator.git.list(project).map(\.branch) == ["main"])
  }

  @Test func aCheckoutGitListsInAnotherCaseIsStillTheCheckout() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let container = fixture.root.appendingPathComponent("CaseDir", isDirectory: true)
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    let spelled = fixture.root.appendingPathComponent("casedir/wt")
    try await TestRepository.addWorktree(
      onNewBranch: "cased", at: spelled, in: fixture.project.path, using: fixture.runner)
    let cased = try await fixture.worktree(onBranch: "cased")

    try await fixture.coordinator.removeUnlinking(cased, in: fixture.project)

    #expect(!FileManager.default.fileExists(atPath: container.appendingPathComponent("wt").path))
    #expect(try await fixture.coordinator.git.list(fixture.project).map(\.branch) == ["main"])
  }

  @Test func aCloneThatTookAStaleRecordsPathIsNotTrashed() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let (stale, path) = try await fixture.worktreeWithItsDirectoryGone()
    _ = try await fixture.runner.run(
      ["clone", "-q", fixture.project.path.path, path.path], in: fixture.root)

    await #expect(throws: WorktreePathTaken.self) {
      try await fixture.coordinator.removeUnlinking(stale, in: fixture.project)
    }

    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent(".git").path))
  }

  @Test func aLockedWorktreeIsRemovedLockAndAll() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "locked", in: fixture.project, settings: fixture.worktreeSettings)
    _ = try await fixture.runner.run(["worktree", "lock", path.path], in: fixture.project.path)
    let locked = try await fixture.worktree(onBranch: "locked")

    try await fixture.coordinator.removeUnlinking(locked, in: fixture.project)

    #expect(try await fixture.coordinator.git.list(fixture.project).map(\.branch) == ["main"])
  }

  @Test func removingAWorktreeWhoseDirectoryIsGonePrunesIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let project = fixture.project
    let coordinator = fixture.coordinator
    let path = try await coordinator.createThenRunPostCreateHook(
      branch: "ghost", in: project, settings: fixture.worktreeSettings)
    try FileManager.default.removeItem(at: path)

    let ghost = try await fixture.worktree(onBranch: "ghost")
    try await coordinator.removeUnlinking(ghost, in: project)

    #expect(try await coordinator.git.list(project).count == 1)
  }

  /// Both fail: the directory is in the Trash by then, so the caller has to
  /// be able to tell this from a Trash that refused.
  @Test func aRecordNeitherRemoveNorPruneLetsGoOfIsItsOwnFailure() async throws {
    let fake = try FakeGit.make("exit 128")
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)
    let worktree = goneWorktree(of: project, in: fake)

    await #expect(throws: WorktreeRecordRemovalFailure.self) {
      try await WorktreeGit(runner: fake.runner).removeRecord(of: worktree, in: project)
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
    let worktree = goneWorktree(of: project, in: fake)

    await #expect(throws: WorktreeRecordRemovalFailure.self) {
      try await WorktreeGit(runner: fake.runner).removeRecord(of: worktree, in: project)
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
    let worktree = goneWorktree(of: project, in: fake)

    await #expect(throws: WorktreeRecordRemovalFailure.self) {
      try await WorktreeGit(runner: fake.runner).removeRecord(of: worktree, in: project)
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
    let worktree = goneWorktree(of: project, in: fake)

    try await WorktreeGit(runner: fake.runner).removeRecord(of: worktree, in: project)
  }

  @Test func aForgetOnAGitThatRefusesTheNulFormStillReadsWhetherTheRecordWent() async throws {
    let fake = try FakeGit.make(
      """
      case " $* " in *" -z "*) echo "error: unknown switch \\`z'" >&2; exit 129 ;; esac
      case "$1 $2" in "worktree remove") exit 128 ;; esac
      printf 'worktree /repos/demo\\nHEAD 1111111\\nbranch refs/heads/main\\n\\n'
      """)
    defer { fake.tearDown() }
    let gone = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-trees/gone"), projectID: fake.directory.path,
      head: "2222222", branch: "gone")

    try await WorktreeGit(runner: fake.runner).removeRecord(
      of: gone, in: Project(path: fake.directory))
  }

  /// A worktree on branch `gone` whose directory was never made.
  private func goneWorktree(of project: Project, in fake: FakeGit) -> Worktree {
    Worktree(
      path: fake.directory.appendingPathComponent("gone"), projectID: project.id, head: "a",
      branch: "gone")
  }
}
