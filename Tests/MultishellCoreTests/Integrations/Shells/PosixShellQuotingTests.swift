import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct PosixShellQuotingTests {
  @Test func plainArgumentsPassThroughAndOthersAreSingleQuoted() {
    #expect(PosixShellQuoting.commandLine(["/usr/bin/top", "-o", "cpu"]) == "/usr/bin/top -o cpu")
    #expect(PosixShellQuoting.quote("My Projects") == "'My Projects'")
    #expect(PosixShellQuoting.quote("it's") == #"'it'\''s'"#)
    #expect(PosixShellQuoting.quote("$HOME") == "'$HOME'")
    #expect(PosixShellQuoting.quote("") == "''")
  }

  @Test func theShellUnquotesToTheOriginalArguments() async throws {
    let arguments = ["My Projects/app", "it's", "$HOME", "", "a\"b", "back\\slash", "tab\there"]
    let script =
      "for a in " + PosixShellQuoting.commandLine(arguments) + "; do printf '%s\\n' \"$a\"; done"
    let output = try await Detached.output(
      of: "/bin/sh", ["-c", script], environment: Scratch.shellEnvironment,
      standardError: .discarded)

    let lines = output.split(
      separator: "\n", omittingEmptySubsequences: false
    ).dropLast().map(String.init)
    #expect(lines == arguments)
  }

}
