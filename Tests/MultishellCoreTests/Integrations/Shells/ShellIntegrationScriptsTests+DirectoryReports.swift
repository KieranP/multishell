import Foundation
import Testing

@testable import MultishellCore

/// The working directory, reported to the terminal as OSC 7.
extension ShellIntegrationScriptsTests {
  @Test func eachPromptReportsTheDirectoryItStartsIn() async throws {
    let output = try await zshOutput(features: nil, input: "exit\n")
    let started = FileManager.default.currentDirectoryPath
    #expect(output.contains(TerminalReports.directoryPrefix))
    #expect(output.contains("\(started)\u{7}"), "with no cd, only a prompt reports it")
  }

  /// A command run after a `cd` on the same line resolves paths from the new
  /// directory, so the report cannot wait for the next prompt.
  @Test func aDirectoryChangeIsReportedBeforeTheRestOfTheLineRuns() async throws {
    let output = try await zshOutput(features: nil, input: "cd /usr && print -n '|'\nexit\n")
    #expect(output.contains("/usr\u{7}|"))
  }

  /// Ghostty reads a raw path in a 2 KB buffer; percent-encoding tripled every
  /// byte outside ASCII and a long path no longer fit.
  @Test func aDirectoryIsReportedAsItIsWithoutEncoding() async throws {
    let input = "mkdir -p \"$HOME/a b%é\" && cd \"$HOME/a b%é\"\nexit\n"
    let output = try await zshOutput(features: nil, input: input)
    #expect(output.contains("/a b%é\u{7}"))
  }

  @Test func aDirectoryWithAControlCharacterIsNotReported() async throws {
    let input = "mkdir -p \"$HOME/x\ty\" && cd \"$HOME/x\ty\" && print -rn -- \"<$PWD>\"\nexit\n"
    let output = try await zshOutput(features: nil, input: input)
    #expect(output.contains("x\ty>"), "the shell is in it")
    #expect(
      output.contains(TerminalReports.directoryPrefix),
      "the directory before it was reported",
    )
    #expect(output.contains("x\ty\u{7}") == false)
  }

  /// `DIR=$(cd "$(dirname …)" && pwd)` is everywhere, and the subshell runs
  /// the cd hook too, which put the report in the captured value.
  @Test func aCdInsideACommandSubstitutionReportsNothingIntoIt() async throws {
    let output = try await zshOutput(
      features: nil,
      input: "x=$(cd /usr; pwd); print -rn -- \"<$x>\"\nexit\n",
    )
    #expect(output.contains("</usr>"))
  }

  /// The cd hook runs inside the command, so a block or function whose output
  /// goes to a file put the report at the top of the file.
  @Test func aCdUnderARedirectReportsToTheTerminalNotTheFile() async throws {
    let output = try await terminalOutput(
      after: "{ cd /usr; print hi; } > ~/out.txt; print -rn -- \"<$(<~/out.txt)>\""
    )
    #expect(output.contains("<hi>"))
    #expect(output.contains(TerminalReports.directoryPrefix), "still reported, to the terminal")
  }
}
