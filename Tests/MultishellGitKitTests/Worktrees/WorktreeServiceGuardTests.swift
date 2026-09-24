import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeServiceGuardTests {
  /// At the descriptor limit a child's output used to vanish and the list
  /// came back empty; taken as a result it emptied the project of its tabs.
  @Test func anEmptyWorktreeListIsAnErrorNotAResult() async throws {
    let fake = try FakeGit.make("exit 0")
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)

    await #expect(throws: ProcessFailure.self) {
      try await WorktreeService(git: fake.runner).list(project)
    }
  }

  @Test func aPathBelowADanglingLinkResolvesItsParentsAsGitDoes() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let link = root.appendingPathComponent("link")
    try FileManager.default.createSymbolicLink(
      at: link, withDestinationURL: root.appendingPathComponent("nowhere"))
    let resolvedRoot = try #require(realpath(root.path, nil))
    defer { free(resolvedRoot) }

    #expect(
      WorktreeService.realPath(of: link.appendingPathComponent("wt"))
        == String(cString: resolvedRoot) + "/link/wt")
  }

  @Test func aListWithTheMainWorktreeIsFine() async throws {
    // `-z`, as the real one is asked: NUL where the newline was.
    let fake = try FakeGit.make(
      "printf 'worktree /repos/demo\\0HEAD 1111111\\0branch refs/heads/main\\0'")
    defer { fake.tearDown() }

    let listed = try await WorktreeService(git: fake.runner).list(Project(path: fake.directory))

    #expect(listed.map(\.branch) == ["main"])
  }

  @Test func aGitThatRefusesTheNulFormIsAskedForTheNewlineOne() async throws {
    let fake = try FakeGit.make(
      """
      case " $* " in *" -z "*) echo "error: unknown switch \\`z'" >&2; exit 129 ;; esac
      printf 'worktree /repos/demo\\nHEAD 1111111\\nbranch refs/heads/main\\n\\n'
      """)
    defer { fake.tearDown() }
    let service = WorktreeService(git: fake.runner)

    let listed = try await service.list(Project(path: fake.directory))
    let main = try await service.mainWorktree(containing: fake.directory)

    #expect(listed.map(\.branch) == ["main"])
    #expect(main.path == "/repos/demo")
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

    try await WorktreeService(git: fake.runner).forget(gone, in: Project(path: fake.directory))
  }

  @Test func aWorktreeLockedWithNoIndexYetIsBeingMadeInWhateverLanguageGitSaysSo() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = try await repo.coordinator.create(
      branch: "making", in: repo.project, settings: repo.trees)
    let admin = repo.project.path.appendingPathComponent(".git/worktrees/making")
    let lock = admin.appendingPathComponent("locked")
    try "initialisiere".write(to: lock, atomically: true, encoding: .utf8)
    try FileManager.default.removeItem(at: admin.appendingPathComponent("index"))
    let linkedAt = try #require(
      FileManager.default.attributesOfItem(atPath: admin.appendingPathComponent("gitdir").path)[
        .modificationDate] as? Date)
    try FileManager.default.setAttributes(
      [.modificationDate: linkedAt.addingTimeInterval(-1)], ofItemAtPath: lock.path)
    _ = try await repo.git.run(
      [
        "worktree", "add", "-q", "-b", "pinned",
        path.deletingLastPathComponent().appendingPathComponent("pinned").path,
      ],
      in: repo.project.path)
    _ = try await repo.git.run(
      [
        "worktree", "lock", "--reason", "initialisiere",
        path.deletingLastPathComponent().appendingPathComponent("pinned").path,
      ],
      in: repo.project.path)

    let listed = try await WorktreeService(git: repo.git).list(repo.project)

    #expect(listed.first { $0.branch == "making" }?.isInitializing == true)
    #expect(listed.first { $0.branch == "pinned" }?.isInitializing == false, "a user's lock")
  }

  @Test func aUsersLockOnAWorktreeAddedWithNoCheckoutIsNotAnAddBeingMade() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = repo.root.appendingPathComponent("unchecked").path
    _ = try await repo.git.run(
      ["worktree", "add", "-q", "--no-checkout", "-b", "unchecked", path], in: repo.project.path)
    _ = try await repo.git.run(
      ["worktree", "lock", "--reason", "on usb", path], in: repo.project.path)
    let admin = repo.project.path.appendingPathComponent(".git/worktrees/unchecked")
    try #require(
      !FileManager.default.fileExists(atPath: admin.appendingPathComponent("index").path))

    let listed = try await WorktreeService(git: repo.git).list(repo.project)

    #expect(listed.first { $0.branch == "unchecked" }?.isLocked == true)
    #expect(listed.first { $0.branch == "unchecked" }?.isInitializing == false)
  }

  @Test func aWorktreeAddedLockedWithNoCheckoutIsNotAnAddBeingMade() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let path = repo.root.appendingPathComponent("parked").path
    _ = try await repo.git.run(
      [
        "worktree", "add", "-q", "--lock", "--reason", "usb", "--no-checkout", "-b", "parked", path,
      ],
      in: repo.project.path)

    let listed = try await WorktreeService(git: repo.git).list(repo.project)

    #expect(listed.first { $0.branch == "parked" }?.isLocked == true)
    #expect(listed.first { $0.branch == "parked" }?.isInitializing == false)
  }

  /// git's own cleanup runs only on a signal it can catch, so a SIGKILL or a
  /// power cut mid-checkout leaves the lock for good.
  @Test func anInitializingLockLeftLongAgoIsAnAbandonedAddNotOneBeingMade() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let reasons = ["killed": "initializing", "worded": "initialisiere"]
    for (branch, reason) in reasons {
      try await repo.coordinator.create(branch: branch, in: repo.project, settings: repo.trees)
      let admin = repo.project.path.appendingPathComponent(".git/worktrees/\(branch)")
      let lock = admin.appendingPathComponent("locked")
      try reason.write(to: lock, atomically: true, encoding: .utf8)
      try FileManager.default.removeItem(at: admin.appendingPathComponent("index"))
      try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -3600)], ofItemAtPath: lock.path)
    }

    let listed = try await WorktreeService(git: repo.git).list(repo.project)

    for branch in reasons.keys {
      #expect(listed.first { $0.branch == branch }?.isInitializing == false, "\(branch)")
      #expect(listed.first { $0.branch == branch }?.isLocked == true, "\(branch)")
    }
  }

  @Test func aCancelledCreateSkipsTheIndexRefresh() async throws {
    let fake = try FakeGit.make(#"echo "$*" >> "$SCRATCH/calls""#)
    defer { fake.tearDown() }
    let stopper = ProcessStopper()
    stopper.stop()

    await WorktreeService(git: fake.runner).refreshIndex(of: fake.directory, stopper: stopper)

    let calls = try? String(
      contentsOf: fake.directory.appendingPathComponent("calls"), encoding: .utf8)
    #expect(calls?.contains("update-index") != true)
  }
}
