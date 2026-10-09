import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentTaskArgumentTests {
  @Test func anOperandTaskFollowsADoubleDashSoOneStartingWithADashIsStillThePrompt() {
    #expect(AgentTaskArgument.operand.arguments(for: "-v is broken") == ["--", "-v is broken"])
  }

  /// Claude's CLI matches the first operand against its subcommands even
  /// behind `--`: `claude -- doctor` runs doctor, not a session.
  @Test func aOneWordOperandTaskCannotSpellASubcommand() {
    let arguments = AgentTaskArgument.operand.arguments(for: "doctor")
    #expect(arguments.first == "--" && arguments.count == 2)
    #expect(arguments.last != "doctor")
    #expect(arguments.last?.trimmingCharacters(in: .whitespaces) == "doctor")
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
