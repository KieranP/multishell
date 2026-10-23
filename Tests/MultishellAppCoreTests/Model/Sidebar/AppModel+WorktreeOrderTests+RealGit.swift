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
    let zulu = try await harness.createWorktree(onBranch: "zulu")
    _ = try await harness.createWorktree(onBranch: "alpha")
    // git prints the committer date in whole seconds, so a clock date can tie every branch
    // and fall back to the name order this test rules out.
    try "work\n".write(
      to: zulu.path.appendingPathComponent("a.txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await harness.git.run(["add", "."], in: zulu.path)
    _ = try await harness.git.run(
      ["commit", "-q", "-m", "later"],
      in: zulu.path,
      environment: ["GIT_COMMITTER_DATE": "2030-01-01T00:00:00Z"],
    )

    await harness.model.refreshBranchScans()

    let dated = harness.model.workspace.worktrees.filter { worktree in
      harness.model.lastCommitDates[worktree.id] != nil
    }
    #expect(
      dated.count == 3,
      "every branch got a date, keyed by the worktree the sidebar asks for",
    )

    let all = harness.model.workspace.worktrees
    var settings = harness.project.settings
    settings.worktreeSortOrder = .committedNewestFirst
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name) == [
        "main", "zulu", "alpha",
      ],
      "zulu was committed to last, so it leads",
    )

    settings.worktreeSortOrder = .committedOldestFirst
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name) == [
        "main", "alpha", "zulu",
      ]
    )

    settings.worktreeSortOrder = .alphabetical
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name) == [
        "main", "alpha", "zulu",
      ],
      "and the name order disagrees with the newest, so the dates were really read",
    )
  }

  /// git makes the directories and the listing reads their birth times. The test sets
  /// those a minute apart, as birth time is only whole-second on some filesystems.
  @Test func theCreatedOrderComesOffTheRealDirectories() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    // Alphabetically first is born first, so newest-first disagrees with the name
    // order; the other way round, a birth-time tie would pass without reading a date.
    for (minute, branch) in ["alpha", "zulu"].enumerated() {
      let worktree = try await harness.createWorktree(onBranch: branch)
      try FileManager.default.setAttributes(
        [.creationDate: Date(timeIntervalSince1970: 1_700_000_000 + 60 * Double(minute))],
        ofItemAtPath: worktree.path.path,
      )
    }
    await harness.model.refreshWorktrees(of: harness.project)

    var settings = harness.project.settings
    settings.worktreeSortOrder = .createdNewestFirst
    harness.model.setSettings(settings, for: harness.project)
    let all = harness.model.workspace.worktrees
    #expect(
      harness.model.orderedWorktrees(
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name) == [
        "main", "zulu", "alpha",
      ],
      "zulu was born second, and sorts after alpha by name",
    )

    settings.worktreeSortOrder = .createdOldestFirst
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.orderedWorktrees(
        all,
        in: harness.project,
        sessions: harness.model.sessionIDsByWorktree,
      ).map(\.name) == [
        "main", "alpha", "zulu",
      ]
    )
  }
}
