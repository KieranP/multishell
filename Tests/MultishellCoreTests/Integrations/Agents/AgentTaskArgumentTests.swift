import Testing

@testable import MultishellCore

@Suite
struct AgentTaskArgumentTests {
  @Test func anOperandTaskFollowsADoubleDashSoOneStartingWithADashIsStillThePrompt() {
    #expect(AgentTaskArgument.operand.arguments(for: "-v is broken") == ["--", "-v is broken"])
  }

  @Test func anOptionTakesTheTaskAfterAnEqualsSignSoTheValueIsNeverReadAsAFlag() {
    #expect(
      AgentTaskArgument.option("--prompt").arguments(for: "--help is wrong")
        == ["--prompt=--help is wrong"])
  }

  /// tcsh refuses a line break inside quotes and inside a quoted variable
  /// read alike, answering "Unmatched '." and starting nothing.
  @Test func aTasksLineBreaksBecomeSpacesAndBlankLinesGo() {
    #expect(
      AgentTaskArgument.operand.arguments(for: "Fix the redirect.\n\nThen\r\nthe tests.")
        == ["--", "Fix the redirect. Then the tests."])
  }
}
