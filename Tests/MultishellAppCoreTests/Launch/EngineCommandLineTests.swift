import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct EngineCommandLineTests {
  @Test func zshAsTheLoginShellNeedsNoOverrideCommand() throws {
    let bashInit = try Scratch.bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      EngineCommandLine.overrideCommand(
        forShell: "/bin/zsh", loginShell: "/bin/zsh", bashInit: bashInit)
        == nil)
  }

  @Test func aChosenShellThatIsNotTheLoginShellIsNamedOutright() throws {
    let bashInit = try Scratch.bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      EngineCommandLine.overrideCommand(
        forShell: "/opt/homebrew/bin/fish", loginShell: "/bin/zsh", bashInit: bashInit)
        == ["/opt/homebrew/bin/fish", "-l"])
    #expect(
      EngineCommandLine.overrideCommand(
        forShell: "/bin/zsh", loginShell: "/bin/bash", bashInit: bashInit)
        == ["/bin/zsh", "-l"])
    #expect(
      EngineCommandLine.overrideCommand(
        forShell: "/bin/bash", loginShell: "/bin/zsh", bashInit: bashInit)?
        .first == "/bin/sh",
      "bash keeps its init file route whichever shell is the login one")
  }

  @Test func bashLaunchesWithTheGeneratedInitFile() throws {
    let bashInit = try Scratch.bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      EngineCommandLine.overrideCommand(forShell: "/bin/bash", bashInit: bashInit)
        == [
          "/bin/sh", "-c",
          "exec /bin/bash --init-file \(AnyShellQuoting.quote(bashInit.path)) -i",
        ])
  }

  /// libghostty runs a surface's command as `exec -l <command>` under bash
  /// (its Exec.zig), and a login bash skips `--init-file`.
  @Test func bashReadsTheInitFileWhenLaunchedAsLibghosttyLaunchesACommand() async throws {
    let bashInit = Scratch.path("bashinit")
    try "echo multishell-init-ran\nexit\n".write(to: bashInit, atomically: true, encoding: .utf8)
    defer { Scratch.remove(bashInit) }
    let home = try Scratch.directory("bash-home")
    defer { Scratch.remove(home) }
    let command = try #require(
      EngineCommandLine.overrideCommand(forShell: "/bin/bash", bashInit: bashInit))
    var environment = Scratch.shellEnvironment
    environment["HOME"] = home.path

    let output = try await Detached.output(
      of: "/bin/bash",
      ["--noprofile", "--norc", "-c", "exec -l \(AnyShellQuoting.commandLine(command))"],
      environment: environment, input: "exit\n")

    #expect(output.contains("multishell-init-ran"))
  }

  @Test func bashWithoutAGeneratedInitFallsBackToAPlainLogin() {
    let missing = URL(fileURLWithPath: "/no/such/init.bash")
    #expect(
      EngineCommandLine.overrideCommand(
        forShell: "/bin/bash", loginShell: "/bin/bash", bashInit: missing)
        == nil)
  }

  @Test func anUnknownShellIsLaunchedPlainly() throws {
    let bashInit = try Scratch.bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      EngineCommandLine.overrideCommand(
        forShell: "/usr/local/bin/fish", loginShell: "/usr/local/bin/fish", bashInit: bashInit)
        == nil)
  }

  @Test func aTabsCommandRunsInsteadOfItsChosenShellAsOneQuotedLine() {
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Agent",
      command: ["claude", "--resume", "a b"], shellOverride: "/opt/homebrew/bin/fish")
    #expect(EngineCommandLine.of(session) == "claude --resume 'a b'")
  }
}
