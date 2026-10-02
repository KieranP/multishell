import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentHookIntegrationEntriesTests: AgentHookFixtures {
  @Test func everyHookedEventGetsOneEntryAndTheSnippetIsValidJSON() throws {
    let entries = AgentHookCatalogue.claude.entries(helper: helper)
    let hooks = try #require(entries["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(AgentHookCatalogue.claude.events.map(\.name)))
    #expect(AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: entries))

    let snippet = AgentHookCatalogue.claude.snippet(helper: helper)
    let parsed = try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any]
    #expect(AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: parsed ?? [:]))
    #expect(snippet.contains("\"timeout\" : 5"))
  }

  @Test func codexsInterruptAndSessionEndGetThreeSecondsAndTheRestFive() throws {
    let hooks = try #require(
      AgentHookCatalogue.codex.entries(helper: helper)["hooks"] as? [String: Any])
    func timeout(_ event: String) -> Int? {
      let groups = hooks[event] as? [[String: Any]]
      return (groups?.first?["hooks"] as? [[String: Any]])?.first?["timeout"] as? Int
    }

    #expect(timeout("Interrupt") == 3)
    #expect(timeout("SessionEnd") == 3)
    for event in hooks.keys where !["Interrupt", "SessionEnd"].contains(event) {
      #expect(timeout(event) == 5, "\(event)")
    }
  }

  /// Gemini counts the timeout in milliseconds, and five seconds spelled as
  /// five would kill the helper before it reached the socket.
  @Test func geminiCountsTheTimeoutInMilliseconds() throws {
    #expect(AgentHookCatalogue.gemini.snippet(helper: helper).contains("\"timeout\" : 5000"))
    #expect(AgentHookCatalogue.claude.snippet(helper: helper).contains("\"timeout\" : 5"))
    #expect(AgentHookCatalogue.codex.snippet(helper: helper).contains("\"timeout\" : 5"))
  }
}
