import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellLaunchTests {
  private func bashInitThatExists() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-bashinit-\(UUID().uuidString).bash")
    try "".write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  @Test func zshLaunchesPlainlyAndCarriesHooksThroughTheEnvironment() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/zsh", loginShell: "/bin/zsh", bashInit: bashInit)
        == nil)
  }

  @Test func aChosenShellThatIsNotTheLoginShellIsNamedOutright() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
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
    defer { try? FileManager.default.removeItem(at: bashInit) }
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/bash", bashInit: bashInit)
        == [
          "/bin/sh", "-c",
          "exec /bin/bash --init-file \(PosixShellQuoting.quote(bashInit.path)) -i",
        ],
      "through sh, so Ghostty applies no bash injection of its own")
  }

  @Test func bashWithoutAGeneratedInitFallsBackToAPlainLogin() {
    let missing = URL(fileURLWithPath: "/no/such/init.bash")
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/bash", loginShell: "/bin/bash", bashInit: missing)
        == nil)
  }

  @Test func anUnknownShellIsLaunchedPlainly() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    #expect(
      ShellLaunch.overrideCommand(
        forShell: "/usr/local/bin/fish", loginShell: "/usr/local/bin/fish", bashInit: bashInit)
        == nil)
  }

  @Test func theExecAfterAnAgentCarriesTheIntegrationBackIn() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    let zshDir = try Scratch.directory("zdot")
    defer { try? FileManager.default.removeItem(at: zshDir) }

    let ours = PosixShellQuoting.quote(zshDir.path)
    let script =
      "if [ -f \"${GHOSTTY_RESOURCES_DIR-}/shell-integration/zsh/.zshenv\" ]; then "
      + "ZDOTDIR=\"$GHOSTTY_RESOURCES_DIR/shell-integration/zsh\" GHOSTTY_ZSH_ZDOTDIR=\(ours) "
      + "exec /bin/zsh -l; else ZDOTDIR=\(ours) exec /bin/zsh -l; fi"
    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/zsh", zshDirectory: zshDir, bashInit: bashInit)
        == "exec /bin/sh -c \(PosixShellQuoting.quote(script))",
      "the engine's bootstrap first where there is one, ours where it looks for the displaced one")
    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/bash", zshDirectory: zshDir, bashInit: bashInit)
        == "exec /bin/bash --init-file \(PosixShellQuoting.quote(bashInit.path)) -i")
    let missing = URL(fileURLWithPath: "/no/such")
    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/zsh", zshDirectory: missing, bashInit: missing)
        == "exec /bin/zsh -l")
    #expect(
      ShellLaunch.execCommandLine(
        forShell: "/usr/local/bin/fish", zshDirectory: zshDir, bashInit: bashInit)
        == "exec /usr/local/bin/fish -l")
  }
}
