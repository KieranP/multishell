import Testing

@testable import MultishellCore

/// The pane's title, the directory at a prompt and the command while it runs.
extension ShellIntegrationScriptsTests {
  @Test func aRealZshTitlesThePaneWithItsDirectoryAndThenTheCommand() async throws {
    let output = try await zshOutput(features: "title", input: "cd\necho hi\nexit\n")
    #expect(
      output.contains(TerminalReports.title("~")),
      "the directory at a prompt, home as a tilde",
    )
    #expect(output.contains(TerminalReports.title("echo hi")), "the command while it runs")
  }

  @Test func aDeepDirectoryIsTitledByItsLastThreeParts() async throws {
    let input = "mkdir -p ~/a/b/c/d/e && cd ~/a/b/c/d/e\nexit\n"
    let output = try await zshOutput(features: "title", input: input)
    #expect(output.contains(TerminalReports.title("…/c/d/e")))
  }

  @Test func aTitleIsLeftAloneWhenTheUsersFeaturesLeaveItOut() async throws {
    let output = try await zshOutput(features: "cursor", input: "true\nexit\n")
    #expect(output.contains(TerminalReports.cursorShape(5)), "the features that are on still ran")
    #expect(output.contains(TerminalReports.anyTitle) == false)
  }
}
