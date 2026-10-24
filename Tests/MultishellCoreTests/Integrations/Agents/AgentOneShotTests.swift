import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentOneShotTests {
  private static let prompt = "Name this branch."

  private static func oneShot(_ id: String) throws -> AgentOneShot {
    try #require(AgentCatalogue.agent(id)).oneShot
  }

  private static func arguments(
    _ id: String,
    model: String? = nil,
    effort: String? = nil,
    prompt: String = prompt,
  ) throws -> [String] {
    try oneShot(id).arguments(prompt: prompt, model: model, effort: effort)
  }

  @Test func eachAgentRunsOnePromptWithNoToolThatCouldTouchTheWorktree() throws {
    #expect(
      try Self.arguments("claude")
        == [
          "-p", "--no-session-persistence", "--strict-mcp-config", "--setting-sources", "user",
          "--tools", "", "--", Self.prompt,
        ]
    )
    #expect(
      try Self.arguments("codex")
        == [
          "exec", "--sandbox", "read-only", "--ephemeral", "--color", "never", "-c",
          "mcp_servers={}", "--", Self.prompt,
        ]
    )
    #expect(try Self.arguments("gemini") == ["--approval-mode", "plan", "--prompt=\(Self.prompt)"])
    #expect(
      try Self.arguments("copilot") == [
        "--silent", "--no-ask-user", "--disable-builtin-mcps", "--deny-tool=shell",
        "--deny-tool=write", "--prompt=\(Self.prompt)",
      ]
    )
    #expect(try Self.arguments("opencode") == ["run", "--standalone", "--", Self.prompt])
  }

  @Test func opencodeTakesNoPermissionFlagSoItsConfigDeniesEveryOne() throws {
    #expect(
      try Self.oneShot("opencode").environment
        == [
          "OPENCODE_CONFIG_CONTENT": #"{"permission":"deny"}"#,
          "OPENCODE_DISABLE_PROJECT_CONFIG": "1",
        ]
    )
    for id in ["claude", "codex", "gemini", "copilot"] {
      #expect(try Self.oneShot(id).environment.isEmpty)
    }
  }

  @Test func aModelAndAnEffortGoBeforeThePromptInEachAgentsSpelling() throws {
    #expect(
      try Self.arguments("claude", model: "sonnet", effort: "low").suffix(6)
        == ["--model", "sonnet", "--effort", "low", "--", Self.prompt]
    )
    #expect(
      try Self.arguments("codex", model: "gpt-6-luna", effort: "high").suffix(6)
        == ["--model", "gpt-6-luna", "-c", "model_reasoning_effort=high", "--", Self.prompt]
    )
    #expect(
      try Self.arguments("copilot", model: "gpt-5.5", effort: "minimal").suffix(5)
        == ["--model", "gpt-5.5", "--reasoning-effort", "minimal", "--prompt=\(Self.prompt)"]
    )
    #expect(
      try Self.arguments("opencode", model: "anthropic/claude-haiku-5-5").suffix(4)
        == ["--model", "anthropic/claude-haiku-5-5", "--", Self.prompt]
    )
  }

  @Test func anAgentWithNoEffortFlagIsPassedNoEffortWhateverItIsAsked() throws {
    for id in ["gemini", "opencode"] {
      let oneShot = try Self.oneShot(id)
      #expect(!oneShot.takesEffort)
      #expect(oneShot.models.allSatisfy { $0.efforts.isEmpty })
      #expect(
        oneShot.arguments(prompt: Self.prompt, model: nil, effort: "high")
          == oneShot.arguments(prompt: Self.prompt, model: nil, effort: nil)
      )
    }
  }

  @Test func everyModelOfAnAgentWithAnEffortFlagOffersEfforts() throws {
    for id in ["claude", "codex", "copilot"] {
      let oneShot = try Self.oneShot(id)
      #expect(oneShot.takesEffort)
      #expect(oneShot.models.allSatisfy { !$0.efforts.isEmpty }, "\(id)")
    }
  }

  @Test func theAgentsDefaultModelOffersOnlyTheEffortsEveryModelTakes() throws {
    let codex = try Self.oneShot("codex")
    #expect(codex.efforts(forModel: "gpt-6-sol").contains("ultra"))
    #expect(!codex.efforts(forModel: nil).contains("ultra"))
    #expect(codex.efforts(forModel: nil) == ["low", "medium", "high", "xhigh"])
  }

  @Test func aModelTheCatalogueDoesNotListOffersTheDefaultModelsEffortsAsItRunsAsThat() throws {
    let codex = try Self.oneShot("codex")
    #expect(codex.efforts(forModel: "gpt-4-retired") == codex.efforts(forModel: nil))
  }

  @Test func eachAgentListsAModelOnce() {
    for agent in AgentCatalogue.agents {
      let ids = agent.oneShot.models.map(\.id)
      #expect(!ids.isEmpty, "\(agent.id)")
      #expect(Set(ids).count == ids.count, "\(agent.id)")
    }
  }

  @Test func thePromptKeepsItsLineBreaksSinceNoShellReadsIt() throws {
    let prompt = "Name this.\n\nCommits:\n- Fix it"
    #expect(try Self.arguments("claude", prompt: prompt).last == prompt)
    #expect(try Self.arguments("gemini", prompt: prompt).last == "--prompt=\(prompt)")
  }

  @Test func aPromptOpeningWithADashIsNeverReadAsAFlag() throws {
    #expect(try Self.arguments("codex", prompt: "-h").suffix(2) == ["--", "-h"])
    #expect(try Self.arguments("copilot", prompt: "-h").last == "--prompt=-h")
  }
}
