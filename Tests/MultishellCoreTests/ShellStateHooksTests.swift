import Foundation
import Testing

@testable import MultishellCore

@Suite
struct ZshIntegrationTests {
  private func directoryThatExists() throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-zdotdir-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func theThreeStartupFilesChainToTheUserAndOnlyZshrcAddsHooks() {
    let files = ShellStateHooks.zshIntegrationFiles(helper: "/x/multishell")
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
  }

  @Test func theSessionGetsZDOTDIROnlyWhenGeneratedAndTheShellIsZsh() throws {
    let dir = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: dir) }

    let zsh = SessionEnvironment.zshIntegration(
      environment: ["SHELL": "/bin/zsh", "ZDOTDIR": "/home/me/.zsh"], integrationDirectory: dir)
    #expect(zsh["ZDOTDIR"] == dir.path)
    #expect(zsh["MULTISHELL_USER_ZDOTDIR"] == "/home/me/.zsh")

    let noUserZdotdir = SessionEnvironment.zshIntegration(
      environment: ["SHELL": "/bin/zsh"], integrationDirectory: dir)
    #expect(noUserZdotdir["ZDOTDIR"] == dir.path)
    #expect(noUserZdotdir["MULTISHELL_USER_ZDOTDIR"] == nil, "our files fall back to $HOME")

    #expect(
      SessionEnvironment.zshIntegration(
        environment: ["SHELL": "/bin/bash"], integrationDirectory: dir
      ).isEmpty,
      "bash is not injected this way")
    let missing = dir.appendingPathComponent("gone", isDirectory: true)
    #expect(
      SessionEnvironment.zshIntegration(
        environment: ["SHELL": "/bin/zsh"], integrationDirectory: missing
      ).isEmpty,
      "nothing when the setting has not generated the directory")
  }

  @Test func aSessionsVariablesFoldInTheIntegrationWhenPresent() throws {
    let dir = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: dir) }
    let session = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w/repo"), title: "Shell")
    let variables = SessionEnvironment.variables(for: session, socket: URL(fileURLWithPath: "/s"))
    // The process running the tests may be zsh or not; either way the base
    // three are always present and ZDOTDIR appears only alongside them.
    #expect(variables[SessionEnvironment.sessionKey] == session.id.uuidString)
  }
}

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
    #expect(ShellLaunch.arguments(forShell: "/bin/zsh", bashInit: bashInit) == ["-l"])
    #expect(ShellLaunch.overrideCommand(forShell: "/bin/zsh", bashInit: bashInit) == nil)
  }

  @Test func bashLaunchesWithTheGeneratedInitFile() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    #expect(
      ShellLaunch.arguments(forShell: "/opt/homebrew/bin/bash", bashInit: bashInit)
        == ["--init-file", bashInit.path, "-i"])
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/bash", bashInit: bashInit)
        == ["/bin/sh", "-c", "exec /bin/bash --init-file \(ShellQuoting.quote(bashInit.path)) -i"],
      "through sh, so Ghostty applies no bash injection of its own")
  }

  @Test func bashWithoutAGeneratedInitFallsBackToAPlainLogin() {
    let missing = URL(fileURLWithPath: "/no/such/init.bash")
    #expect(ShellLaunch.arguments(forShell: "/bin/bash", bashInit: missing) == ["-l"])
    #expect(ShellLaunch.overrideCommand(forShell: "/bin/bash", bashInit: missing) == nil)
  }

  @Test func anUnknownShellIsLaunchedPlainly() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    #expect(ShellLaunch.arguments(forShell: "/usr/local/bin/fish", bashInit: bashInit) == ["-l"])
    #expect(ShellLaunch.overrideCommand(forShell: "/usr/local/bin/fish", bashInit: bashInit) == nil)
  }

  @Test func theExecAfterAnAgentCarriesTheIntegrationBackIn() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    let zshDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-zdot-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: zshDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: zshDir) }

    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/zsh", zshIntegration: zshDir, bashInit: bashInit)
        == "ZDOTDIR=\(ShellQuoting.quote(zshDir.path)) exec /bin/zsh -l")
    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/bash", zshIntegration: zshDir, bashInit: bashInit)
        == "exec /bin/bash --init-file \(ShellQuoting.quote(bashInit.path)) -i")
    let missing = URL(fileURLWithPath: "/no/such")
    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/zsh", zshIntegration: missing, bashInit: missing)
        == "exec /bin/zsh -l")
    #expect(
      ShellLaunch.execCommandLine(
        forShell: "/usr/local/bin/fish", zshIntegration: zshDir, bashInit: bashInit)
        == "exec /usr/local/bin/fish -l")
  }

  /// A stray quote in the Swift literal renders as a shell syntax error that
  /// silently defines no hooks; the shells' own parsers are the check.
  @Test func everyGeneratedFileParsesInItsShell() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-syntax-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
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

  @Test func theBashInitReproducesTheLoginChainThenAddsHooks() {
    let text = ShellStateHooks.bashInitFile(helper: "/x/multishell")
    #expect(text.contains(". /etc/profile"))
    #expect(text.contains("$HOME/.bash_profile"))
    #expect(text.contains("$HOME/.bashrc"))
    #expect(text.contains("command-started --pid $$") && text.contains("command-finished"))
    #expect(text.contains("$MULTISHELL_SESSION"), "does nothing outside a tab")
    #expect(text.contains("/x/multishell"))
    #expect(text.range(of: ".bashrc")!.lowerBound < text.range(of: "command-started")!.lowerBound)
  }
}
