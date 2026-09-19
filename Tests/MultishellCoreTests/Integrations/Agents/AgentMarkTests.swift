import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentMarkTests {
  @Test func everyCatalogueAgentHasAMarkAndAParsableTint() {
    for agent in AgentCatalogue.agents {
      #expect(AgentCatalogue.mark(agent.id) == agent.mark)
      guard agent.markTint != nil else { continue }
      #expect(
        AgentCatalogue.markTintRGB(agent.id) != nil,
        "\(agent.id) names a tint the hex parser rejects")
    }
  }

  @Test func anAgentWithNoMarkOfItsOwnFallsBackToLetters() {
    #expect(AgentCatalogue.mark("aider") == .monogram("Ai"))
    #expect(AgentCatalogue.markTintRGB("aider") == nil)
    #expect(AgentCatalogue.mark(AgentCatalogue.customID) == .monogram("Cc"))
  }

  /// A workspace written by a newer build names agents this one has never
  /// heard of; the tab still has to draw something.
  @Test func anUnknownIdGetsLettersFromTheIdItself() {
    #expect(AgentCatalogue.mark("wezterm-agent") == .monogram("Wa"))
    #expect(AgentCatalogue.markTintRGB("wezterm-agent") == nil)
  }

  @Test func lettersTakeOneFromEachOfTheFirstTwoWords() {
    #expect(AgentMark.letters(of: "Claude Code") == "Cc")
    #expect(AgentMark.letters(of: "opencode") == "Op")
    #expect(AgentMark.letters(of: "cursor-agent") == "Ca")
    #expect(AgentMark.letters(of: "claude-3") == "Cl")
    #expect(AgentMark.letters(of: "x") == "X")
    #expect(AgentMark.letters(of: "42") == "?")
    #expect(AgentMark.letters(of: "") == "?")
  }
}
