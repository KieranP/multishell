import Testing

@testable import MultishellAppCore

@Suite
struct NewWorktreeDraftAgentTests {
  private let installed = ["claude", "codex"]

  private func fitted(
    startsByDefault: Bool = true, preferred: String? = "codex", offered: [String]? = nil
  ) -> NewWorktreeDraft {
    var draft = NewWorktreeDraft(projectID: "/repos/a")
    draft.fitAgent(
      startsByDefault: startsByDefault, preferred: preferred, offered: offered ?? installed)
    return draft
  }

  @Test func theSwitchStartsWhereTheProjectAutoStartsAndOnItsAgent() {
    let on = fitted()
    #expect(on.startsAgent && on.agentID == "codex")
    #expect(on.firstTab == .agent("codex", task: ""))

    let off = fitted(startsByDefault: false)
    #expect(!off.startsAgent && off.agentID == "codex", "the picker is ready if switched on")
    #expect(off.firstTab == .shell)
  }

  @Test func theTaskIsTrimmedAndRidesWithThePickedAgent() {
    var draft = fitted()
    draft.agentID = "claude"
    draft.task = "  Fix the redirect\n"

    #expect(draft.firstTab == .agent("claude", task: "Fix the redirect"))
    draft.startsAgent = false
    #expect(draft.firstTab == .shell, "switched off, the task is not sent anywhere")
  }

  @Test func anAgentThatIsNotInstalledGivesWayToTheFirstThatIs() {
    let draft = fitted(preferred: "gemini")
    #expect(draft.agentID == "claude")
    #expect(draft.offersAgents)
  }

  @Test func withNothingOfferedTheCreateSettingsDecideAsBeforeThePathScanAnswered() {
    let draft = fitted(offered: [])
    #expect(!draft.offersAgents)
    #expect(draft.firstTab == nil)
  }

  @Test func anotherProjectTakesItsOwnAgentAndKeepsTheTypedTask() {
    var draft = fitted()
    draft.agentID = "claude"
    draft.task = "Fix the redirect"

    draft.fitAgent(startsByDefault: false, preferred: "codex", offered: installed)

    #expect(draft.agentID == "codex" && !draft.startsAgent)
    #expect(draft.task == "Fix the redirect")
  }

  @Test func aPathScanLandingLateOffersTheProjectsAgentAndLeavesAPickAlone() {
    var draft = fitted(offered: [])
    draft.offerAgents(installed)
    #expect(draft.agentID == "codex" && draft.startsAgent)

    draft.agentID = "claude"
    draft.offerAgents(["claude", "codex", "gemini"])
    #expect(draft.agentID == "claude")
  }
}
