import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite @MainActor
struct AppModelDebugGitCommandsTests {
  @Test func everyGitRunWhileDebugToolsAreOnIsCountedUnderItsWorktree() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let model = harness.model
    let git = try #require(model.coordinator?.git)
    let worktree = try #require(model.workspace.worktrees.first)
    model.enableDebugTools()
    harness.clearStatuses()

    _ = await git.isRepository(worktree.path)
    await model.takeDebugSample()

    #expect((model.debugHistory.latest?.gitRunsStartedCount ?? 0) >= 1)
    let row = try #require(
      model.debugGitCommands(for: .oneMinute).first { $0.command == "rev-parse --git-dir" })
    #expect(row.slowestLocation?.worktreeName == model.displayName(of: worktree))
    #expect((row.tally.peakMemory ?? 0) > 0, "read as git exited, too short for any sample")

    model.setDebugToolsEnabled(false)
    _ = await git.isRepository(worktree.path)
    #expect(git.runLog.drain() == .empty)
  }

  @Test func onlyTheRunsInsideTheRangeAreCounted() {
    let harness = Harness()
    harness.model.enableDebugTools()
    for sequence in 0..<70 {
      let runs = sequence == 0 ? [GitRun.sample("fetch")] : sequence == 69 ? [.sample()] : []
      harness.model.debugHistory.append(
        .sample(sequence: sequence, gitCommands: GitCommandTally.byCommand(runs)))
    }

    #expect(harness.model.debugGitCommands(for: .oneMinute).map(\.command) == ["status"])
    #expect(
      Set(harness.model.debugGitCommands(for: .fiveMinutes).map(\.command)) == ["status", "fetch"])
  }

  @Test func theCommandThatTookLongestInAllComesFirstAndATieGoesByName() {
    let harness = Harness()
    harness.model.enableDebugTools()
    harness.model.debugHistory.append(
      .sample(
        sequence: 0,
        gitCommands: GitCommandTally.byCommand([
          .sample("status", milliseconds: 10), .sample("status", milliseconds: 10),
          .sample("log", milliseconds: 50), .sample("diff", milliseconds: 20),
          .sample("branch", milliseconds: 20),
        ])))

    #expect(
      harness.model.debugGitCommands(for: .oneMinute).map(\.command)
        == ["log", "branch", "diff", "status"])
  }
}
