import Foundation
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitInitializingTests {
  @Test func aWorktreeLockedWithNoIndexYetIsBeingMadeInWhateverLanguageGitSaysSo() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "making",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )
    let admin = fixture.project.path.appendingPathComponent(".git/worktrees/making")
    let lock = admin.appendingPathComponent("locked")
    try "initialisiere".write(to: lock, atomically: true, encoding: .utf8)
    try FileManager.default.removeItem(at: admin.appendingPathComponent("index"))
    let linkedAt = try #require(
      FileManager.default.attributesOfItem(atPath: admin.appendingPathComponent("gitdir").path)[
        .modificationDate
      ] as? Date
    )
    try FileManager.default.setAttributes(
      [.modificationDate: linkedAt.addingTimeInterval(-1)],
      ofItemAtPath: lock.path,
    )
    try await TestRepository.addWorktree(
      onNewBranch: "pinned",
      at: path.deletingLastPathComponent().appendingPathComponent("pinned"),
      in: fixture.project.path,
      using: fixture.runner,
    )
    _ = try await fixture.runner.run(
      [
        "worktree", "lock", "--reason", "initialisiere",
        path.deletingLastPathComponent().appendingPathComponent("pinned").path,
      ],
      in: fixture.project.path,
    )

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)

    #expect(listed.first { $0.branch == "making" }?.isInitializing == true)
    #expect(listed.first { $0.branch == "pinned" }?.isInitializing == false, "a user's lock")
  }

  @Test func aUsersLockOnAWorktreeAddedWithNoCheckoutIsNotAnAddBeingMade() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.root.appendingPathComponent("unchecked").path
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "--no-checkout", "-b", "unchecked", path],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(
      ["worktree", "lock", "--reason", "on usb", path],
      in: fixture.project.path,
    )
    let admin = fixture.project.path.appendingPathComponent(".git/worktrees/unchecked")
    try #require(
      !FileManager.default.fileExists(atPath: admin.appendingPathComponent("index").path)
    )

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)

    #expect(listed.first { $0.branch == "unchecked" }?.isLocked == true)
    #expect(listed.first { $0.branch == "unchecked" }?.isInitializing == false)
  }

  @Test func aWorktreeAddedLockedWithNoCheckoutIsNotAnAddBeingMade() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.root.appendingPathComponent("parked").path
    _ = try await fixture.runner.run(
      [
        "worktree", "add", "-q", "--lock", "--reason", "usb", "--no-checkout", "-b", "parked", path,
      ],
      in: fixture.project.path,
    )

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)

    #expect(listed.first { $0.branch == "parked" }?.isLocked == true)
    #expect(listed.first { $0.branch == "parked" }?.isInitializing == false)
  }

  /// git's own cleanup runs only on a signal it can catch, so a SIGKILL or a
  /// power cut mid-checkout leaves the lock for good.
  @Test func anInitializingLockLeftLongAgoIsAnAbandonedAddNotOneBeingMade() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let reasons = ["killed": "initializing", "worded": "initialisiere"]
    for (branch, reason) in reasons {
      try await fixture.coordinator.createThenRunPostCreateHook(
        branch: branch,
        in: fixture.project,
        settings: fixture.worktreeSettings,
      )
      let admin = fixture.project.path.appendingPathComponent(".git/worktrees/\(branch)")
      let lock = admin.appendingPathComponent("locked")
      try reason.write(to: lock, atomically: true, encoding: .utf8)
      try FileManager.default.removeItem(at: admin.appendingPathComponent("index"))
      try FileManager.default.setAttributes(
        [.modificationDate: Date(timeIntervalSinceNow: -3600)],
        ofItemAtPath: lock.path,
      )
    }

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)

    for branch in reasons.keys {
      #expect(listed.first { $0.branch == branch }?.isInitializing == false, "\(branch)")
      #expect(listed.first { $0.branch == branch }?.isLocked == true, "\(branch)")
    }
  }
}
