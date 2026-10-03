import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit
@testable import MultishellProcess

@Suite(.serialized) @MainActor
struct AppModelLoginEnvironmentTests {
  @Test func theAgentPathNoteNamesWhereThePathCameFrom() {
    let harness = Harness()
    #expect(harness.model.agentPathNote == t("agents.path-asking"))

    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: [:], source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    #expect(harness.model.agentPathNote == t("agents.path-from-login-shell", "/bin/zsh"))

    harness.model.loginEnvironment = LoginShellEnvironment(
      variables: [:], source: .processFallback(reason: "timed out after 5s"))
    #expect(harness.model.agentPathNote == t("agents.path-fallback", "timed out after 5s"))
  }

  /// A saved agent tab clicked while PATH is still being scanned must not read as missing,
  /// so the environment and what was found on it land together.
  @Test func theEnvironmentIsNotKnownBeforeItsPathHasBeenScanned() async throws {
    let harness = Harness()
    let refresh = Task { await harness.model.refreshLoginEnvironment() }
    try await waitUntil { harness.model.loginEnvironment != nil }
    #expect(harness.model.loginEnvironment != nil)
    #expect(harness.model.shellDetection != .empty, "/etc/shells alone fills this")
    #expect(
      harness.model.agentDetection
        == AgentDetection(searchPath: harness.model.loginEnvironment?.path))
    await refresh.value
  }

  @Test func theLoginEnvironmentFeedsDetection() async throws {
    let harness = Harness()
    try harness.installFakeAgent("claude")
    #expect(harness.model.loginEnvironment == nil)
    await harness.model.refreshLoginEnvironment()
    #expect(harness.model.loginEnvironment?.path != nil)
    #expect(
      harness.model.agentDetection.found[AgentCatalogue.claudeID] != nil, "found on that PATH")
    #expect(
      harness.model.agentDetection
        == AgentDetection(searchPath: harness.model.loginEnvironment?.path))
  }

  @Test func aLoginShellThatAnswersIsRecordedAndNotLogged() async {
    let harness = Harness()
    await harness.model.refreshLoginEnvironment()
    #expect(harness.model.loginEnvironment?.source == .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    #expect(harness.platform.logged.isEmpty)
  }

  @Test func aLoginShellThatCouldNotAnswerIsRecordedAndLogged() async {
    let harness = Harness()
    let variables = await harness.model.captureLoginEnvironment().variables
    harness.model.captureLoginEnvironment = {
      LoginShellEnvironment(variables: variables, source: .processFallback(reason: "timed out"))
    }
    await harness.model.refreshLoginEnvironment()
    #expect(harness.model.loginEnvironment?.source == .processFallback(reason: "timed out"))
    #expect(harness.platform.logged.count == 1)
  }

  @Test func theLoginEnvironmentsGitKeepsTheCountsAndTheMergeWidthLaunchHad() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let path = try #require(ProcessInfo.processInfo.environment["PATH"])
    harness.model.captureLoginEnvironment = {
      LoginShellEnvironment(
        variables: ["PATH": path, "HOME": harness.root.path],
        source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    }
    let launched = try #require(harness.model.coordinator).git

    await harness.model.refreshLoginEnvironment()

    let rebuilt = try #require(harness.model.coordinator).git
    #expect(rebuilt.readState.untrackedMemo === launched.readState.untrackedMemo)
    #expect(rebuilt.readState.mergeSlots === launched.readState.mergeSlots)
  }

  @Test(arguments: [true, false])
  func aGitFoundOnlyOnTheLoginPathIsTimedJustWhileDebugToolsAreOn(enabled: Bool) async throws {
    let harness = Harness()
    try harness.installFakeAgent("git")
    harness.model.enableDebugTools()

    await harness.model.refreshLoginEnvironment()
    if !enabled { harness.model.setDebugToolsEnabled(false) }
    let git = try #require(harness.model.coordinator?.git)
    _ = git.runLog.drain()
    _ = await git.isRepository(harness.root)

    #expect(git.runLog.drain().startedCount == (enabled ? 1 : 0))
  }
}
