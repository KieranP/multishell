import Testing

@testable import MultishellCore

/// The end of a command and its status, which zsh writes now that the
/// engine's own integration is off.
extension ShellIntegrationScriptsTests {
  @Test func aRealZshTellsTheTerminalACommandEndedAndWithWhatStatus() async throws {
    let output = try await zshOutput(features: nil, input: "false\ntrue\nexit\n")
    #expect(output.contains(PromptMarks.commandEnd(1)))
    #expect(output.contains(PromptMarks.commandEnd(0)))
  }

  @Test func aPromptWithNoCommandBeforeItReportsNoEnd() async throws {
    let output = try await zshOutput(features: nil, input: "\nexit\n")
    #expect(output.contains(PromptMarks.input), "the hooks ran")
    #expect(output.contains(PromptMarks.anyCommandEnd) == false)
  }
}
