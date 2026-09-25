import Foundation
import Testing

@testable import MultishellAppUI

/// Installing the command line tool runs one `do shell script` as root, so a
/// path that ended the script text early would run as AppleScript.
@Suite(.serialized)
@MainActor
struct AppleScriptHandlerTests {
  /// The same script, without the clause that would ask for an administrator,
  /// so what the shell would be given can be read rather than run.
  private let probe = """
    on buildCommand(target, link)
      return "mkdir -p /usr/local/bin && ln -sf " & quoted form of target & " " & quoted form of link
    end buildCommand
    """

  @Test func aHandlerGivesBackWhatItReturned() throws {
    let command = try AppleScriptHandler.call(
      probe, handler: "buildCommand", arguments: ["/a/multishell", "/usr/local/bin/multishell"])
    #expect(
      command == "mkdir -p /usr/local/bin && ln -sf '/a/multishell' '/usr/local/bin/multishell'")
  }

  /// A home directory holding a quote used to close the AppleScript literal
  /// and leave the rest to run as AppleScript, as root.
  @Test func aPathHoldingQuotesAndSemicolonsArrivesAsOneArgument() throws {
    let hostile = #"/Users/od"d/x'; rm -rf /"#
    let command = try AppleScriptHandler.call(
      probe, handler: "buildCommand", arguments: [hostile, "/usr/local/bin/multishell"])

    #expect(command?.contains("rm -rf /") == true, "it is in there")
    #expect(command?.hasSuffix("'/usr/local/bin/multishell'") == true, "and it ended nothing")
    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-n", "-c", try #require(command)]
    try shell.run()
    shell.waitUntilExit()
    #expect(shell.terminationStatus == 0, "and the shell parses it as one command")
  }

  @Test func theInstallScriptIsValidAppleScript() throws {
    #expect(throws: Never.self) {
      try AppleScriptHandler.compile(AppleScriptHandler.installToolScript)
    }
  }

  @Test func aScriptThatWillNotCompileThrowsWhatAppleScriptSaid() {
    #expect(throws: AppleScriptFailed.self) {
      try AppleScriptHandler.call("on x(", handler: "x", arguments: [])
    }
  }
}
