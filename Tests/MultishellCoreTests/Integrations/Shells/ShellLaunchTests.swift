import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellLaunchTests {
  private func bashInitThatExists() throws -> URL {
    let url = Scratch.path("bashinit")
    try "".write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  @Test func zshAsTheLoginShellNeedsNoOverrideCommand() throws {
    let bashInit = try bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/zsh", loginShell: "/bin/zsh", bashInit: bashInit)
        == nil)
  }

  @Test func aChosenShellThatIsNotTheLoginShellIsNamedOutright() throws {
    let bashInit = try bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      ShellLaunch.overrideCommand(
        forShell: "/opt/homebrew/bin/fish", loginShell: "/bin/zsh", bashInit: bashInit)
        == ["/opt/homebrew/bin/fish", "-l"])
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/zsh", loginShell: "/bin/bash", bashInit: bashInit)
        == ["/bin/zsh", "-l"])
    #expect(
      ShellLaunch.overrideCommand(
        forShell: "/bin/bash", loginShell: "/bin/zsh", bashInit: bashInit)?
        .first == "/bin/sh",
      "bash keeps its init file route whichever shell is the login one")
  }

  @Test func bashLaunchesWithTheGeneratedInitFile() throws {
    let bashInit = try bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/bash", bashInit: bashInit)
        == [
          "/bin/sh", "-c",
          "exec /bin/bash --init-file \(PosixShellQuoting.quote(bashInit.path)) -i",
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
      ShellLaunch.overrideCommand(forShell: "/bin/bash", bashInit: bashInit))
    var environment = Scratch.shellEnvironment
    environment["HOME"] = home.path

    let output = try await Detached.output(
      of: "/bin/bash",
      ["--noprofile", "--norc", "-c", "exec -l \(PosixShellQuoting.commandLine(command))"],
      environment: environment, input: "exit\n")

    #expect(output.contains("multishell-init-ran"))
  }

  @Test func bashWithoutAGeneratedInitFallsBackToAPlainLogin() {
    let missing = URL(fileURLWithPath: "/no/such/init.bash")
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/bash", loginShell: "/bin/bash", bashInit: missing)
        == nil)
  }

  @Test func anUnknownShellIsLaunchedPlainly() throws {
    let bashInit = try bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    #expect(
      ShellLaunch.overrideCommand(
        forShell: "/usr/local/bin/fish", loginShell: "/usr/local/bin/fish", bashInit: bashInit)
        == nil)
  }

  @Test func theExecAfterAnAgentCarriesTheIntegrationBackIn() throws {
    let bashInit = try bashInitThatExists()
    defer { Scratch.remove(bashInit) }
    let zshDirectory = try Scratch.directory("zdot")
    defer { Scratch.remove(zshDirectory) }

    #expect(
      ShellLaunch.execArguments(
        forShell: "/bin/zsh", zshDirectory: zshDirectory, bashInit: bashInit)
        == ["exec", "env", "ZDOTDIR=\(zshDirectory.path)", "/bin/zsh", "-l"])
    #expect(
      ShellLaunch.execArguments(
        forShell: "/bin/bash", zshDirectory: zshDirectory, bashInit: bashInit)
        == ["exec", "/bin/bash", "--init-file", bashInit.path, "-i"])
    let missing = URL(fileURLWithPath: "/no/such")
    #expect(
      ShellLaunch.execArguments(forShell: "/bin/zsh", zshDirectory: missing, bashInit: missing)
        == ["exec", "/bin/zsh", "-l"])
    #expect(
      ShellLaunch.execArguments(
        forShell: "/usr/local/bin/fish", zshDirectory: zshDirectory, bashInit: bashInit)
        == ["exec", "/usr/local/bin/fish", "-l"])
  }
}
