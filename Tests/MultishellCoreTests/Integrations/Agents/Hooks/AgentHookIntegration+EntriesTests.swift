import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentHookIntegrationEntriesTests: AgentHookFixtures {
  @Test func everyHookedEventGetsAnEntryAndTheSnippetIsValidJSON() throws {
    let hooksObject = AgentHookCatalogue.claude.hooksObject(helper: helper)
    let hooks = try #require(hooksObject["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == Set(AgentHookCatalogue.claude.events.map(\.name)))
    #expect(AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: hooksObject))

    let snippet = AgentHookCatalogue.claude.snippet(helper: helper)
    let parsed = try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any]
    #expect(AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: parsed ?? [:]))
    #expect(try timeouts(in: snippet) == [5])
  }

  @Test func codexsInterruptAndSessionEndGetThreeSecondsAndTheRestFive() throws {
    let hooks = try #require(
      AgentHookCatalogue.codex.hooksObject(helper: helper)["hooks"] as? [String: Any])
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

  /// Five seconds spelled as five would kill the helper before it reached the
  /// socket.
  @Test func geminiCountsTheTimeoutInMilliseconds() throws {
    #expect(try timeouts(in: AgentHookCatalogue.gemini.snippet(helper: helper)) == [5000])
    #expect(try timeouts(in: AgentHookCatalogue.claude.snippet(helper: helper)) == [5])
    #expect(try timeouts(in: AgentHookCatalogue.codex.snippet(helper: helper)) == [3, 5])
  }

  private func timeouts(in snippet: String) throws -> Set<Int> {
    func collect(_ value: Any) -> [Int] {
      if let object = value as? [String: Any] {
        return object.flatMap { key, inner in
          key == "timeout" ? [inner as? Int].compactMap { $0 } : collect(inner)
        }
      }
      if let list = value as? [Any] { return list.flatMap(collect) }
      return []
    }
    return Set(collect(try JSONSerialization.jsonObject(with: Data(snippet.utf8))))
  }
}
