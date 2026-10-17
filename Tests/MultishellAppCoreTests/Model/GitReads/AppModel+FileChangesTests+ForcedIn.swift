import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelFileChangesTests {
  /// `check-ignore` is asked about the folder, and a folder holding a tracked
  /// file must not read as ignored; worktrees.md records the rule.
  @Test func anEditToAFileForcedInUnderAnIgnoredFolderIsRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = harness.project.path
    let build = path.appending(path: "build", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
    try "build/\n".write(to: path.appending(path: ".gitignore"), atomically: true, encoding: .utf8)
    try "kept\n".write(to: build.appending(path: "kept.txt"), atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", ".gitignore"], in: path)
    _ = try await harness.git.run(["add", "-f", "build/kept.txt"], in: path)
    _ = try await harness.git.run(["commit", "-qm", "forced"], in: path)
    let main = try #require(harness.worktree(onBranch: "main"))
    await harness.model.noteFileChanges([build])
    harness.clearStatuses()
    try "changed\n".write(to: build.appending(path: "kept.txt"), atomically: true, encoding: .utf8)

    await harness.model.noteFileChanges([build])

    try await waitUntil { harness.model.statuses[main.id] != nil }
    #expect(harness.model.statuses[main.id]?.changedFiles == 1)
  }
}
