import Foundation
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

  /// The shell that receives the line must give back exactly the arguments.
  @Test func theShellUnquotesToTheOriginalArguments() async throws {
    let arguments = ["My Projects/app", "it's", "$HOME", "", "a\"b", "back\\slash", "tab\there"]
    let script =
      "for a in " + PosixShellQuoting.commandLine(arguments) + "; do printf '%s\\n' \"$a\"; done"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let lines = String(decoding: data, as: UTF8.self).split(
      separator: "\n", omittingEmptySubsequences: false
    ).dropLast().map(String.init)
    #expect(lines == arguments)
  }

}
