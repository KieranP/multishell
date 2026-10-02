import Testing

@testable import MultishellCore

@Suite
struct AgentMarkTests {
  @Test func lettersTakeOneFromEachOfTheFirstTwoWords() {
    #expect(AgentMark.letters(of: "Claude Code") == "Cc")
    #expect(AgentMark.letters(of: "opencode") == "Op")
    #expect(AgentMark.letters(of: "some-agent") == "Sa")
    #expect(AgentMark.letters(of: "claude-3") == "Cl")
    #expect(AgentMark.letters(of: "x") == "X")
    #expect(AgentMark.letters(of: "42") == "?")
    #expect(AgentMark.letters(of: "") == "?")
  }
}
