import Foundation
import MultishellCore
import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelLoginEnvironmentTests {
  @Test func theAgentPathNoteNamesWhereThePathCameFrom() {
    let h = Harness()
    #expect(h.model.agentPathNote == t("agents.path-asking"))

    h.model.loginEnvironment = LoginShellEnvironment(
      variables: [:], source: .loginShell(URL(fileURLWithPath: "/bin/zsh")))
    #expect(h.model.agentPathNote == t("agents.path-from-login-shell", "/bin/zsh"))

    h.model.loginEnvironment = LoginShellEnvironment(
      variables: [:], source: .processFallback(reason: "timed out after 5s"))
    #expect(h.model.agentPathNote == t("agents.path-fallback", "timed out after 5s"))
  }

  /// A saved agent tab clicked while PATH is still being scanned must not read as missing,
  /// so the environment and what was found on it land together.
  @Test func theEnvironmentIsNotKnownBeforeItsPathHasBeenScanned() async {
    let h = Harness()
    let refresh = Task { await h.model.refreshLoginEnvironment() }
    while h.model.loginEnvironment == nil { try? await Task.sleep(for: .milliseconds(1)) }
    #expect(h.model.shellDetection != .empty, "/etc/shells alone fills this")
    #expect(h.model.agentDetection == AgentDetection(searchPath: h.model.loginEnvironment?.path))
    await refresh.value
  }

  @Test func theLoginEnvironmentFeedsDetection() async throws {
    let h = Harness()
    try h.installFakeAgent("claude")
    #expect(h.model.loginEnvironment == nil)
    await h.model.refreshLoginEnvironment()
    #expect(h.model.loginEnvironment?.path != nil)
    #expect(h.model.agentDetection.found[AgentCatalogue.claudeID] != nil, "found on that PATH")
    #expect(h.model.agentDetection == AgentDetection(searchPath: h.model.loginEnvironment?.path))
  }

  @Test func theModelListensForTheAppComingToTheFrontAndCapturesTheLoginShell() async {
    let h = Harness()
    #expect(h.platform.onDidBecomeActive != nil, "the model listens from its init")
    await h.model.refreshLoginEnvironment()
    let environment = h.model.loginEnvironment
    #expect(environment != nil)
    if case .processFallback = environment?.source {
      #expect(h.platform.logged.count == 1, "a shell that could not answer is logged, not shown")
    } else {
      #expect(h.platform.logged.isEmpty)
    }
  }
}
