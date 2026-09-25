import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

/// Every other commit-order test sets dates by hand, so only this one notices the scan's
/// answer never reaching the model, or reaching it under the wrong key.
extension AppModelWorktreeOrderTests {
  @Test func theCommitOrderComesOffARealScan() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Cut alphabetically last first, so a name order and a commit order
    // disagree and only the right one can pass.
    for branch in ["zulu", "alpha"] {
      await harness.model.createWorktree(
        branch: branch, basedOn: nil, createBranch: true, in: harness.project)
    }
    // git prints the committer date in whole seconds, so a clock date can tie every branch
    // and fall back to the name order this test rules out.
    let zulu = try #require(harness.model.workspace.worktrees.first { $0.branch == "zulu" })
    try "work\n".write(
      to: zulu.path.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    _ = try await harness.git.run(["add", "."], in: zulu.path)
    _ = try await harness.git.run(
      ["commit", "-q", "-m", "later"], in: zulu.path,
      environment: ["GIT_COMMITTER_DATE": "2030-01-01T00:00:00Z"])

    await harness.model.refreshMergeStates()

    let dated = harness.model.workspace.worktrees.filter { harness.model.lastCommits[$0.id] != nil }
    #expect(dated.count == 3, "every branch got a date, keyed by the worktree the sidebar asks for")

    let all = harness.model.workspace.worktrees
    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .committedNewestFirst
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "zulu", "alpha",
      ],
      "zulu was committed to last, so it leads")

    settings.worktreeSortOrder = .committedOldestFirst
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "alpha", "zulu",
      ])

    settings.worktreeSortOrder = .alphabetical
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "alpha", "zulu",
      ],
      "and the name order disagrees with the newest, so the dates were really read")
  }

  /// The created orders off the same real repository: git makes the
  /// directories, so the birth times are real ones.
  @Test func theCreatedOrderComesOffTheRealDirectories() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Alphabetically first is created first, so newest-first disagrees with the name
    // order; the other way round, a birth-time tie would pass without reading a date.
    for branch in ["alpha", "zulu"] {
      await harness.model.createWorktree(
        branch: branch, basedOn: nil, createBranch: true, in: harness.project)
      // A second apart: birth time is only whole-second on some
      // filesystems, and a tie here is what this test exists to rule out.
      try? await Task.sleep(for: .milliseconds(1100))
    }

    var settings = harness.model.workspace.project(harness.project.id)!.settings
    settings.worktreeSortOrder = .createdNewestFirst
    harness.model.updateSettings(settings, for: harness.project)
    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "zulu", "alpha",
      ],
      "zulu was created second, and sorts after alpha by name")

    settings.worktreeSortOrder = .createdOldestFirst
    harness.model.updateSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(all, in: harness.project).map(\.name) == [
        "main", "alpha", "zulu",
      ])
  }
}
