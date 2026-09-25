import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct ShellCommandTests {
  @Test func runsACommandLineThroughTheShellWithEnvironment() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let out = try await ShellCommand.runScript(
      "echo $MULTISHELL_BRANCH | tr a-z A-Z", in: shell.home,
      environment: shell.environment.merging(["MULTISHELL_BRANCH": "feat"]) { $1 },
      shellPath: shell.path)
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "FEAT")
  }

  @Test func aLaunchedCommandSaysHowItEnded() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    func launch(_ command: String, in directory: URL) async throws {
      try await ShellCommand.launch(
        command, in: directory, environment: shell.environment, shellPath: shell.path)
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

    try await ShellCommand.launch(
      "for f in *.nomatch; do :; done; true", in: shell.home, environment: shell.environment,
      shellPath: shell.path)
  }

  /// A shim holding the editor open holds this call too, which kept two pipes and a login
  /// shell per click; the shell sees a pipe where a descriptor count in this process cannot.
  @Test func aLaunchedCommandIsGivenNoPipes() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    for stream in ["1", "2"] {
      await #expect(throws: ProcessFailure.self, "stream \(stream)") {
        try await ShellCommand.launch(
          "test -p /dev/fd/\(stream)", in: shell.home, environment: shell.environment,
          shellPath: shell.path)
      }
      let captured = try await ShellCommand.runScript(
        "test -p /dev/fd/\(stream) && printf pipe", in: shell.home,
        environment: shell.environment, shellPath: shell.path)
      #expect(captured == "pipe", "which is what `runScript` gives it, for the contrast")
    }
  }
}
