import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct AgentLaunchTests {
  @Test func resumeUsesTheCatalogueOrGivesUp() {
    let claude = AgentCatalogue.agent("claude")!
    #expect(AgentLaunch.arguments(for: claude, resume: false) == ["claude"])
    #expect(AgentLaunch.arguments(for: claude, resume: true) == ["claude", "--continue"])
    let gemini = AgentCatalogue.agent("gemini")!
    #expect(AgentLaunch.arguments(for: gemini, resume: true) == ["gemini", "--resume", "latest"])
    // Every agent in the catalogue resumes today, so the no-flag arm is
    // shown against a descriptor rather than left uncovered.
    let flagless = AgentDescriptor(
      id: "flagless",
      name: "Flagless",
      executable: "flagless",
      taskArgument: .operand,
      mark: .monogram("Fl"),
      oneShot: claude.oneShot,
    )
    #expect(
      AgentLaunch.arguments(for: flagless, resume: true) == nil,
      "no resume flag: plain shell",
    )
  }

  @Test func aReportedConversationIsResumedByIdWhereTheAgentTakesOne() {
    func resumed(_ id: String) -> [String]? {
      AgentLaunch.arguments(for: AgentCatalogue.agent(id)!, resume: true, conversation: "c1")
    }
    #expect(resumed("claude") == ["claude", "--resume", "c1"])
    #expect(resumed("codex") == ["codex", "resume", "c1"])
    #expect(resumed("gemini") == ["gemini", "--resume", "c1"])
    #expect(resumed("copilot") == ["copilot", "--resume=c1"])
    #expect(resumed("opencode") == ["opencode", "--continue"], "no hook reports its id")
    #expect(
      AgentLaunch.arguments(
        for: AgentCatalogue.agent("claude")!,
        resume: false,
        conversation: "c1",
      )
        == ["claude"],
      "a new tab starts afresh",
    )
  }
}
