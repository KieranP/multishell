import Foundation
import Testing

@testable import MultishellAppUI

/// Installing the command line tool runs one `do shell script` as root, so a
/// path that ended the script text early would run as AppleScript.
@Suite(.serialized)
@MainActor
struct AppleScriptRunnerTests {
  @Test func aHandlerGivesBackWhatItReturned() throws {
    let command = try AppleScriptRunner.call(
      MacPlatform.installToolScript,
      handler: "installCommand",
      arguments: ["/a/multishell", "/usr/local/bin", "/usr/local/bin/multishell"],
    )
    #expect(
      command
        == "mkdir -p '/usr/local/bin' && ln -sfh '/a/multishell' '/usr/local/bin/multishell'"
    )
  }

  /// A home directory holding a quote used to close the AppleScript literal
  /// and leave the rest to run as AppleScript, as root.
  @Test func aPathHoldingQuotesAndSemicolonsArrivesAsOneArgument() throws {
    let hostile = #"/Users/od"d/x'; rm -rf /"#
    let command = try AppleScriptRunner.call(
      MacPlatform.installToolScript,
      handler: "installCommand",
      arguments: [hostile, "/usr/local/bin", "/usr/local/bin/multishell"],
    )

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
      try AppleScriptRunner.compile(MacPlatform.installToolScript)
    }
  }

  @Test func aScriptThatWillNotCompileThrowsWhatAppleScriptSaid() {
    let failure = #expect(throws: AppleScriptFailed.self) {
      try AppleScriptRunner.call("on x(", handler: "x", arguments: [])
    }
    #expect(failure?.message.isEmpty == false)
  }
}
