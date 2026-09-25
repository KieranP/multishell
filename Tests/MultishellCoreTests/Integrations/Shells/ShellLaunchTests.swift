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

  /// A stray quote in the Swift literal renders as a shell syntax error that
  /// silently defines no hooks; the shells' own parsers are the check.
  @Test func everyGeneratedFileParsesInItsShell() throws {
    let directory = try Scratch.directory("syntax")
    defer { try? FileManager.default.removeItem(at: directory) }
    var files: [(String, String)] = ShellStateHooks.zshIntegrationFiles(helper: "/x/multishell")
      .map { ("/bin/zsh", $0.value) }
    files.append(("/bin/bash", ShellStateHooks.bashInitFile(helper: "/x/multishell")))
    for (index, (shell, contents)) in files.enumerated() {
      guard FileManager.default.isExecutableFile(atPath: shell) else { continue }
      let file = directory.appendingPathComponent("file\(index)")
      try contents.write(to: file, atomically: true, encoding: .utf8)
      let process = Process()
      process.executableURL = URL(fileURLWithPath: shell)
      process.arguments = ["-n", file.path]
      let errors = Pipe()
      process.standardError = errors
      try process.run()
      process.waitUntilExit()
      let message = String(
        decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      #expect(process.terminationStatus == 0, "\(shell) -n: \(message)")
    }
  }

  /// A placeholder left in reports no command, and the live-shell tests
  /// catch that only where both shells are installed.
  @Test func everyPlaceholderIsFilledInAndTheAgentsAreNamed() {
    var files = ShellStateHooks.zshIntegrationFiles(helper: "/x/multishell")
    files["init.bash"] = ShellStateHooks.bashInitFile(helper: "/x/multishell")
    for (name, text) in files {
      #expect(!text.contains("__MULTISHELL_"), "\(name) still holds a placeholder")
    }
    for script in [files[".zshrc"] ?? "", files["init.bash"] ?? ""] {
      for id in ["claude", "codex", "opencode"] {
        #expect(script.contains(id), "the shell cannot match \(id) without its name")
      }
    }
  }

  @Test func theBashInitReproducesTheLoginChainThenAddsHooks() {
    let text = ShellStateHooks.bashInitFile(helper: "/x/multishell")
    #expect(text.contains(". /etc/profile"))
    #expect(text.contains("$HOME/.bash_profile"))
    #expect(text.contains("$HOME/.bashrc"))
    #expect(text.contains("command-started --pid $$") && text.contains("command-finished"))
    #expect(
      text.contains("${MULTISHELL_SESSION-}"),
      "does nothing outside a tab, and reading it does not trip a shell run with nounset")
    #expect(text.contains("/x/multishell"))
    #expect(text.range(of: ".bashrc")!.lowerBound < text.range(of: "command-started")!.lowerBound)
  }
}
