import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellIntegrationScriptsTests {
  /// A stray quote in the Swift literal renders as a shell syntax error that
  /// silently defines no hooks; the shells' own parsers are the check.
  @Test func everyGeneratedFileParsesInItsShell() throws {
    let directory = try Scratch.directory("syntax")
    defer { Scratch.remove(directory) }
    var files: [(String, String)] = ShellIntegrationScripts.forZsh(
      helper: "/x/multishell"
    )
    .map { ("/bin/zsh", $0.value) }
    files.append(("/bin/bash", ShellIntegrationScripts.forBash(helper: "/x/multishell")))
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

  @Test func eachIncludedFileIsJoinedInAtTheIndentOfItsLine() {
    let zshrc = ShellIntegrationScripts.forZsh(helper: "/x/multishell")[".zshrc"] ?? ""
    let bash = ShellIntegrationScripts.forBash(helper: "/x/multishell")
    #expect(!zshrc.contains("# include ") && !bash.contains("# include "))
    #expect(zshrc.contains("\n  _multishell_terminal_precmd() {"))
    #expect(zshrc.contains("\n  _multishell_report_state() {"))
    #expect(bash.contains("\n  _multishell_relayed() {"))
    #expect(bash.contains("\n  _multishell_prompt_marks() {"))
  }

  /// A placeholder left in reports no command, and the live-shell tests
  /// catch that only where both shells are installed.
  @Test func everyPlaceholderIsFilledInAndTheAgentsAreNamed() {
    var files = ShellIntegrationScripts.forZsh(helper: "/x/multishell")
    files["init.bash"] = ShellIntegrationScripts.forBash(helper: "/x/multishell")
    for (name, text) in files {
      #expect(!text.contains("__MULTISHELL_"), "\(name) still holds a placeholder")
    }
    for script in [files[".zshrc"] ?? "", files["init.bash"] ?? ""] {
      for executable in AgentCatalogue.agents.map(\.executable) {
        #expect(
          script.contains(executable), "the shell cannot match \(executable) without its name")
      }
    }
  }

  @Test func theBashInitReproducesTheLoginChainThenAddsHooks() {
    let text = ShellIntegrationScripts.forBash(helper: "/x/multishell")
    #expect(text.contains(". /etc/profile"))
    #expect(text.contains("$HOME/.bash_profile"))
    #expect(text.contains("$HOME/.bashrc"))
    #expect(text.contains("command-started --pid ") && text.contains("command-finished --exit "))
    #expect(
      text.contains("${MULTISHELL_SESSION-}"),
      "does nothing outside a tab, and reading it does not trip a shell run with nounset")
    #expect(text.contains("/x/multishell"))
    #expect(text.range(of: ".bashrc")!.lowerBound < text.range(of: "command-started")!.lowerBound)
  }

  @Test func theThreeStartupFilesChainToTheUserAndOnlyZshrcAddsHooks() {
    let files = ShellIntegrationScripts.forZsh(helper: "/x/multishell")
    #expect(Set(files.keys) == [".zshenv", ".zprofile", ".zshrc"])
    for (name, contents) in files {
      #expect(contents.contains("source \"${ZDOTDIR:-$HOME}/\(name)\""), "\(name) chains")
    }
    let zshrc = files[".zshrc"] ?? ""
    #expect(zshrc.contains("command-started --pid $$"), "the shell's pid, for the watch")
    #expect(zshrc.contains("command-finished --exit"))
    #expect(zshrc.contains("$MULTISHELL_SESSION"), "does nothing outside a tab")
    #expect(zshrc.contains("/x/multishell"), "references the helper by its stable path")
    #expect(
      zshrc.contains("add-zsh-hook zshexit _multishell_zshexit") && zshrc.contains("state idle"),
      "exit runs preexec but no precmd, so it clears on the way out")
    #expect(files[".zshenv"]?.contains("command-started") == false, "hooks only in .zshrc")
    let capture = "export MULTISHELL_USER_ZDOTDIR=\"$ZDOTDIR\""
    for name in [".zshenv", ".zprofile"] {
      #expect(files[name]?.contains(capture) == true, "\(name) may relocate ZDOTDIR")
    }
    #expect(zshrc.contains(capture) == false, "the last file hands it back instead")
  }

  private func historyFile(
    userZdotdir: URL? = nil, userZshrc: String? = nil
  ) async throws -> (file: String, integration: GeneratedIntegration) {
    let integration = try GeneratedIntegration(helper: "/x/multishell")
    if let userZdotdir {
      try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    }
    if let userZshrc {
      try userZshrc.write(
        to: (userZdotdir ?? integration.home).appendingPathComponent(".zshrc"), atomically: true,
        encoding: .utf8)
    }
    var environment = integration.environment(termProgram: nil)
    environment["ZDOTDIR"] = integration.zshDirectory.path
    environment["MULTISHELL_USER_ZDOTDIR"] = userZdotdir?.path
    let file = try await Detached.output(
      of: "/bin/zsh", ["-l", "-i", "-c", "print -r -- \"$HISTFILE\""],
      environment: environment, in: integration.home, standardError: .discarded)
    return (file.trimmingCharacters(in: .newlines), integration)
  }

  private var systemRcSetsHistory: Bool {
    (try? String(contentsOfFile: "/etc/zshrc", encoding: .utf8))?.contains("HISTFILE=") == true
  }

  @Test func aTabsHistoryGoesWhereTheUsersOwnShellWouldPutIt() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let plain = try await historyFile()
    defer { plain.integration.tearDown() }
    #expect(!plain.file.hasPrefix(plain.integration.zshDirectory.path), "\(plain.file)")
    if systemRcSetsHistory {
      #expect(plain.file == plain.integration.home.appendingPathComponent(".zsh_history").path)
    }

    let root = try Scratch.directory("histfile-user")
    defer { Scratch.remove(root) }
    let own = root.appendingPathComponent("zdot", isDirectory: true)
    let relocated = try await historyFile(userZdotdir: own)
    defer { relocated.integration.tearDown() }
    if systemRcSetsHistory {
      #expect(relocated.file == own.appendingPathComponent(".zsh_history").path)
    }

    let chosen = try await historyFile(userZshrc: "HISTFILE=/elsewhere/history\n")
    defer { chosen.integration.tearDown() }
    #expect(chosen.file == "/elsewhere/history", "the user's own setting stands")
  }
}
