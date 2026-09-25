import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AgentHooksRowTests {
  private func detection(_ ids: [String]) -> AgentDetection {
    AgentDetection(
      found: Dictionary(uniqueKeysWithValues: ids.map { ($0, URL(fileURLWithPath: "/bin/\($0)")) }))
  }

  /// An agent this machine has gets a row, and so does one whose hooks are
  /// still installed after it has gone: those have to be removable.
  @Test func rowsAreForTheAgentsHereAndTheHooksLeftBehind() {
    let rows = AgentHooksRow.rows(
      detection: detection(["claude", "gemini", "nonesuch"]), installed: ["codex"])

    #expect(rows.map(\.id) == ["claude", "codex", "gemini"], "catalogue order")
    #expect(rows.first { $0.id == "codex" }?.isInstalled == true)
    #expect(rows.first { $0.id == "claude" }?.isInstalled == false)
    #expect(!rows.contains { $0.id == "nonesuch" }, "no hooks to offer")
    #expect(!rows.contains { $0.id == "copilot" }, "not on this machine")
  }

  @Test func aRowWhoseHooksAnOlderBuildWroteAsksForAnUpdate() throws {
    let rows = AgentHooksRow.rows(
      detection: detection(["claude", "codex"]), installed: ["claude", "codex"], stale: ["codex"])

    #expect(try #require(rows.first { $0.id == "codex" }).wantsUpdate)
    #expect(try !#require(rows.first { $0.id == "claude" }).wantsUpdate)
  }

  @Test func eachRowNamesItsFileAndWhatWritingItDoes() throws {
    let rows = AgentHooksRow.rows(
      detection: detection(["claude", "codex", "copilot", "opencode"]), installed: [])
    let claude = try #require(rows.first { $0.id == "claude" })
    let codex = try #require(rows.first { $0.id == "codex" })
    let copilot = try #require(rows.first { $0.id == "copilot" })
    let openCode = try #require(rows.first { $0.id == "opencode" })

    #expect(claude.displayPath == "~/.claude/settings.json")
    #expect(claude.info.contains("Other hooks in ~/.claude/settings.json stay"))
    #expect(claude.contentsLabel == "JSON")
    #expect(copilot.info.contains("Multishell's own file"), "nothing of the user's to keep")
    #expect(
      codex.info.contains("/hooks in Codex once to trust Multishell's"),
      "it runs no hook it has not been told to trust")
    #expect(!claude.info.contains("/hooks in Codex"))
    #expect(openCode.contentsLabel == "Plugin")
    for row in rows { #expect(row.info.contains(row.name)) }
  }

  @Test func everyRowsInfoFitsTwoHundredCharacters() {
    let rows = AgentHooksRow.rows(
      detection: detection(AgentHookCatalogue.integrations.map(\.id)), installed: [])
    #expect(rows.count == AgentHookCatalogue.integrations.count)
    for row in rows { #expect(row.info.count <= 200, "\(row.id) is \(row.info.count) characters") }
  }
}
