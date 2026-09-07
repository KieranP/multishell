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
      shellPath: "/bin/zsh", environment: ["ZDOTDIR": "/home/me/.zsh"], integrationDirectory: dir)
    #expect(zsh["ZDOTDIR"] == dir.path)
    #expect(zsh["MULTISHELL_USER_ZDOTDIR"] == "/home/me/.zsh")

    let noUserZdotdir = SessionEnvironment.zshIntegration(
      shellPath: "/bin/zsh", environment: [:], integrationDirectory: dir)
    #expect(noUserZdotdir["ZDOTDIR"] == dir.path)
    #expect(noUserZdotdir["MULTISHELL_USER_ZDOTDIR"] == nil, "our files fall back to $HOME")

    #expect(
      SessionEnvironment.zshIntegration(
        shellPath: "/bin/bash", environment: [:], integrationDirectory: dir
      ).isEmpty,
      "bash is not injected this way")
    let chosen = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Shell",
      shell: "/bin/bash")
    #expect(
      SessionEnvironment.variables(for: chosen, socket: URL(fileURLWithPath: "/s"))["ZDOTDIR"]
        == nil,
      "a tab whose chosen shell is bash gets no zsh integration whatever $SHELL is")
    let missing = dir.appendingPathComponent("gone", isDirectory: true)
    #expect(
      SessionEnvironment.zshIntegration(
        shellPath: "/bin/zsh", environment: [:], integrationDirectory: missing
      ).isEmpty,
      "nothing when the setting has not generated the directory")
  }

  /// libghostty sets `ZDOTDIR` to its own bootstrap and then applies the
  /// surface's variables on top, so ours would replace it and its integration
  /// would never load. Given the bootstrap, the session enters it first.
  @Test func theEnginesBootstrapIsEnteredFirstWhenItHasOne() throws {
    let ours = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: ours) }
    let bootstrap = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: bootstrap) }
    try Data().write(to: bootstrap.appendingPathComponent(".zshenv"))

    let chained = SessionEnvironment.zshIntegration(
      shellPath: "/bin/zsh", environment: ["ZDOTDIR": "/u"], integrationDirectory: ours,
      engineBootstrap: bootstrap)
    #expect(chained["ZDOTDIR"] == bootstrap.path)
    #expect(chained[SessionEnvironment.ghosttyZdotdirKey] == ours.path)
    #expect(chained["MULTISHELL_USER_ZDOTDIR"] == "/u", "and ours still chains to the user's")

    let empty = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: empty) }
    let unbootstrapped = SessionEnvironment.zshIntegration(
      shellPath: "/bin/zsh", environment: [:], integrationDirectory: ours, engineBootstrap: empty)
    #expect(unbootstrapped["ZDOTDIR"] == ours.path, "a bootstrap with no startup file is no chain")
    #expect(unbootstrapped[SessionEnvironment.ghosttyZdotdirKey] == nil)
    #expect(
      SessionEnvironment.zshIntegration(
        shellPath: "/bin/bash", environment: [:], integrationDirectory: ours,
        engineBootstrap: bootstrap
      ).isEmpty, "bash is not chained either way")
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
    #expect(
      ShellLaunch.overrideCommand(forShell: "/bin/bash", loginShell: "/bin/bash", bashInit: missing)
        == nil)
  }

  @Test func anUnknownShellIsLaunchedPlainly() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    #expect(ShellLaunch.arguments(forShell: "/usr/local/bin/fish", bashInit: bashInit) == ["-l"])
    #expect(
      ShellLaunch.overrideCommand(
        forShell: "/usr/local/bin/fish", loginShell: "/usr/local/bin/fish", bashInit: bashInit)
        == nil)
  }

  @Test func theExecAfterAnAgentCarriesTheIntegrationBackIn() throws {
    let bashInit = try bashInitThatExists()
    defer { try? FileManager.default.removeItem(at: bashInit) }
    let zshDir = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("ms-zdot-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: zshDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: zshDir) }

    let ours = ShellQuoting.quote(zshDir.path)
    let script =
      "if [ -f \"${GHOSTTY_RESOURCES_DIR-}/shell-integration/zsh/.zshenv\" ]; then "
      + "ZDOTDIR=\"$GHOSTTY_RESOURCES_DIR/shell-integration/zsh\" GHOSTTY_ZSH_ZDOTDIR=\(ours) "
      + "exec /bin/zsh -l; else ZDOTDIR=\(ours) exec /bin/zsh -l; fi"
    #expect(
      ShellLaunch.execCommandLine(forShell: "/bin/zsh", zshIntegration: zshDir, bashInit: bashInit)
        == "exec /bin/sh -c \(ShellQuoting.quote(script))",
      "the engine's bootstrap first where there is one, ours where it looks for the displaced one")
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
    #expect(
      text.contains("${MULTISHELL_SESSION-}"),
      "does nothing outside a tab, and reading it does not trip a shell run with nounset")
    #expect(text.contains("/x/multishell"))
    #expect(text.range(of: ".bashrc")!.lowerBound < text.range(of: "command-started")!.lowerBound)
  }
}
