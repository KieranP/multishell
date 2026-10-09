import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct ShellCommandTests {
  @Test func aScriptRunsInTheUsersShellAndSeesTheEnvironmentItIsGiven() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let out = try await ShellCommand.runScript(
      "echo $MULTISHELL_BRANCH | tr a-z A-Z",
      in: shell.home,
      shellPath: shell.path,
      environment: shell.environment.merging(["MULTISHELL_BRANCH": "feat"]) { $1 },
    )
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "FEAT")
  }

  @Test func aLaunchedCommandSaysHowItEnded() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    func launch(_ command: String, in directory: URL) async throws {
      try await ShellCommand.runUncaptured(
        command,
        in: directory,
        shellPath: shell.path,
        environment: shell.environment,
      )
    }
    try await launch("true", in: shell.home)
    await #expect(throws: ProcessFailure.self) {
      try await launch("exit 3", in: shell.home)
    }
    await #expect(throws: (any Error).self) {
      try await launch("true", in: URL(fileURLWithPath: "/no/such/dir"))
    }
  }
  @Test func aLaunchedCommandIsReadAsShUnderZsh() async throws {
    let shell = try ScratchShell("/bin/zsh")
    defer { shell.tearDown() }

    try await ShellCommand.runUncaptured(
      "for f in *.nomatch; do :; done; true",
      in: shell.home,
      shellPath: shell.path,
      environment: shell.environment,
    )
  }

  /// A shim holding the editor open holds this call too, which kept two pipes and a login
  /// shell per click; the shell sees a pipe where a descriptor count in this process cannot.
  @Test func aLaunchedCommandIsGivenNoPipes() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    for stream in ["1", "2"] {
      await #expect(throws: ProcessFailure.self, "stream \(stream)") {
        try await ShellCommand.runUncaptured(
          "test -p /dev/fd/\(stream)",
          in: shell.home,
          shellPath: shell.path,
          environment: shell.environment,
        )
      }
      let captured = try await ShellCommand.runScript(
        "test -p /dev/fd/\(stream) && printf pipe",
        in: shell.home,
        shellPath: shell.path,
        environment: shell.environment,
      )
      #expect(captured == "pipe", "which is what `runScript` gives it, for the contrast")
    }
  }

  @Test func aStoppedScriptIsAFailureThatSaysSo() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    do {
      _ = try await ShellCommand.runScript(
        "sleep 30",
        in: shell.home,
        shellPath: shell.path,
        environment: shell.environment,
        timeout: .milliseconds(300),
      )
      Issue.record("the script did not fail")
    } catch let failure as ProcessFailure {
      #expect(failure.stopReason == .timedOut(after: .milliseconds(300)))
    }
  }
}
