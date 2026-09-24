import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeForgetScopeTests {
  /// A repository-wide prune after the trash would also forget a worktree
  /// whose drive is unmounted at that moment; see Docs/design/worktrees.md.
  @Test func removingOneWorktreeKeepsAnotherWhoseDirectoryIsAway() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    try await repo.coordinator.create(branch: "gone", in: repo.project, settings: repo.trees)
    let away = try await repo.coordinator.create(
      branch: "away", in: repo.project, settings: repo.trees)
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)
    let gone = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "gone" })

    try await repo.coordinator.remove(gone, in: repo.project)

    let listed = try await repo.coordinator.refresh(repo.project)
    #expect(listed.map(\.branch) == ["main", "away"], "the away worktree is still on record")
    try FileManager.default.moveItem(at: aside, to: away)
    #expect(try await repo.head(of: away) == repo.head(of: repo.project.path), "and works again")
  }

  @Test func forgettingAStaleRecordKeepsAnotherWorktreeWhoseDirectoryIsAway() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "old", in: repo.project, settings: repo.trees)
    let away = try await repo.coordinator.create(
      branch: "away", in: repo.project, settings: repo.trees)
    let stale = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "old" })
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    let aside = away.deletingLastPathComponent().appendingPathComponent("away-aside")
    try FileManager.default.moveItem(at: away, to: aside)

    try await repo.coordinator.remove(stale, in: repo.project)

    let listed = try await repo.coordinator.refresh(repo.project)
    #expect(listed.map(\.branch) == ["main", "away"])
    try FileManager.default.moveItem(at: aside, to: away)
    #expect(try await repo.head(of: away) == repo.head(of: repo.project.path))
  }

  @Test func aDirectoryThatTookAStaleRecordsPathIsNotTrashed() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "old", in: repo.project, settings: repo.trees)
    let stale = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "old" })
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    let notes = path.appendingPathComponent("notes.txt")
    try "mine\n".write(to: notes, atomically: true, encoding: .utf8)

    try await repo.coordinator.remove(stale, in: repo.project)

    #expect(FileManager.default.fileExists(atPath: notes.path))
    #expect(try await repo.coordinator.refresh(repo.project).map(\.branch) == ["main"])
  }

  @Test func theDeleteHooksNeverRunAgainstADirectoryThatTookAStaleRecordsPath() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    let path = try await repo.coordinator.create(
      branch: "old", in: project, settings: repo.trees)
    let stale = try #require(
      try await repo.coordinator.refresh(project).first { $0.branch == "old" })
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    project.settings = ProjectSettings(
      preDeleteHook: "touch pre-ran \"$MULTISHELL_WORKTREE_PATH/pre-ran\"",
      postDeleteHook: "touch \"$MULTISHELL_WORKTREE_PATH/post-ran\"")

    try await repo.coordinator.remove(stale, in: project, shellPath: "/bin/sh")

    #expect(try FileManager.default.contentsOfDirectory(atPath: path.path).isEmpty)
    #expect(try await repo.coordinator.refresh(project).map(\.branch) == ["main"])
  }

  @Test func aLockedStaleRecordIsForgottenAndTheDirectoryAtItsPathKept() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "old", in: repo.project, settings: repo.trees)
    _ = try await repo.git.run(
      ["worktree", "lock", "--reason", "external drive", path.path], in: repo.project.path)
    let stale = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "old" })
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
    let notes = path.appendingPathComponent("notes.txt")
    try "mine\n".write(to: notes, atomically: true, encoding: .utf8)

    try await repo.coordinator.remove(stale, in: repo.project)

    #expect(FileManager.default.fileExists(atPath: notes.path))
    #expect(try await repo.coordinator.refresh(repo.project).map(\.branch) == ["main"])
  }

  /// Stands in for a `safe.directory` refusal or a timeout inside the checkout alone.
  @Test func aCheckoutGitCannotReadIsStillRemovedWithItsHooks() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    let path = try await repo.coordinator.create(
      branch: "unread", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(project).first { $0.branch == "unread" })
    let fake = try FakeGit.make(
      """
      case "$*" in *--show-toplevel*) exit 128 ;; esac
      exec git "$@"
      """)
    defer { fake.tearDown() }
    let ran = repo.root.appendingPathComponent("pre-ran")
    project.settings = ProjectSettings(preDeleteHook: "touch \"\(ran.path)\"")
    let coordinator = WorktreeCoordinator(
      service: WorktreeService(git: fake.runner, settlesNewIndex: false))

    try await coordinator.remove(worktree, in: project, shellPath: "/bin/sh")

    #expect(FileManager.default.fileExists(atPath: ran.path))
    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.refresh(project).map(\.branch) == ["main"])
  }

  /// git before 2.31 echoes `--path-format=absolute` back as an unknown flag
  /// and prints the common directory relative to where it ran.
  @Test func aCheckoutIsRemovedWithItsHooksOnAGitThatPredatesPathFormat() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    var project = repo.project
    let path = try await repo.coordinator.create(
      branch: "older", in: project, settings: repo.trees)
    let worktree = try #require(
      try await repo.coordinator.refresh(project).first { $0.branch == "older" })
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
    let ran = repo.root.appendingPathComponent("pre-ran")
    project.settings = ProjectSettings(preDeleteHook: "touch \"\(ran.path)\"")
    let coordinator = WorktreeCoordinator(
      service: WorktreeService(git: fake.runner, settlesNewIndex: false))

    let common = try await coordinator.commonGitDirectory(project)
    try await coordinator.remove(worktree, in: project, shellPath: "/bin/sh")

    #expect(
      common.resolvingSymlinksInPath().path
        == project.path.appendingPathComponent(".git").resolvingSymlinksInPath().path)
    #expect(FileManager.default.fileExists(atPath: ran.path))
    #expect(!FileManager.default.fileExists(atPath: path.path))
    #expect(try await repo.coordinator.refresh(project).map(\.branch) == ["main"])
  }

  @Test func aCheckoutGitListsInAnotherCaseIsStillTheCheckout() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let container = repo.root.appendingPathComponent("CaseDir", isDirectory: true)
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    let spelled = repo.root.appendingPathComponent("casedir/wt")
    _ = try await repo.git.run(
      ["worktree", "add", "-q", "-b", "cased", spelled.path], in: repo.project.path)
    let cased = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "cased" })

    try await repo.coordinator.remove(cased, in: repo.project)

    #expect(!FileManager.default.fileExists(atPath: container.appendingPathComponent("wt").path))
    #expect(try await repo.coordinator.refresh(repo.project).map(\.branch) == ["main"])
  }

  @Test func aCloneThatTookAStaleRecordsPathIsNotTrashed() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "old", in: repo.project, settings: repo.trees)
    let stale = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "old" })
    try FileManager.default.removeItem(at: path)
    _ = try await repo.git.run(
      ["clone", "-q", repo.project.path.path, path.path], in: repo.root)

    await #expect(throws: NotTheCheckout.self) {
      try await repo.coordinator.remove(stale, in: repo.project)
    }

    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent(".git").path))
  }

  @Test func aLockedWorktreeWhoseTrashRefusesStaysLocked() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "pinned", in: repo.project, settings: repo.trees)
    _ = try await repo.git.run(
      ["worktree", "lock", "--reason", "external drive", path.path], in: repo.project.path)
    let pinned = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "pinned" })
    #expect(pinned.isLocked)

    await #expect(throws: TrashFailure.self) {
      try await repo.coordinator.remove(
        pinned, in: repo.project, trash: { _ in throw CocoaError(.fileWriteNoPermission) })
    }

    let after = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "pinned" })
    #expect(after.isLocked, "the lock and its reason are the user's")
    let listed = try await repo.git.run(["worktree", "list", "--porcelain"], in: repo.project.path)
    #expect(listed.contains("locked external drive"))
  }

  /// `remove --force --force` on a directory still in place would unlink it,
  /// so a Trash that returned without taking it must stop the removal.
  @Test func aTrashThatTookNothingStopsBeforeGitIsAsked() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "untouched", in: repo.project, settings: repo.trees)
    try "work\n".write(
      to: path.appendingPathComponent("wip.txt"), atomically: true, encoding: .utf8)
    let worktree = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "untouched" })

    await #expect(throws: TrashFailure.self) {
      try await repo.coordinator.remove(worktree, in: repo.project, trash: { _ in })
    }

    #expect(FileManager.default.fileExists(atPath: path.appendingPathComponent("wip.txt").path))
    #expect(try await repo.coordinator.refresh(repo.project).count == 2, "still on record")
  }

  @Test func aLockedWorktreeIsRemovedLockAndAll() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "locked", in: repo.project, settings: repo.trees)
    _ = try await repo.git.run(["worktree", "lock", path.path], in: repo.project.path)
    let locked = try #require(
      try await repo.coordinator.refresh(repo.project).first { $0.branch == "locked" })

    try await repo.coordinator.remove(locked, in: repo.project)

    #expect(try await repo.coordinator.refresh(repo.project).map(\.branch) == ["main"])
  }
}
