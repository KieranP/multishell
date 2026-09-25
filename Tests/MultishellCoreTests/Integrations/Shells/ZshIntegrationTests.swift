import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ZshIntegrationTests {
  private func directoryThatExists() throws -> URL {
    let url = try Scratch.directory("zdotdir")
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
    let capture = "export MULTISHELL_USER_ZDOTDIR=\"$ZDOTDIR\""
    for name in [".zshenv", ".zprofile"] {
      #expect(files[name]?.contains(capture) == true, "\(name) may relocate ZDOTDIR")
    }
    #expect(zshrc.contains(capture) == false, "the last file hands it back instead")
  }

  private func historyFile(
    userZdotdir: URL? = nil, userZshrc: String? = nil
  ) async throws -> (
    file: String, home: URL, integration: URL
  ) {
    let root = try Scratch.directory("histfile")
    let home = root.appendingPathComponent("home", isDirectory: true)
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    for directory in [home, integration] + (userZdotdir.map { [$0] } ?? []) {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: "/x/multishell") {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    if let userZshrc {
      try userZshrc.write(
        to: (userZdotdir ?? home).appendingPathComponent(".zshrc"), atomically: true,
        encoding: .utf8)
    }
    var environment = [
      "HOME": home.path, "ZDOTDIR": integration.path, "PATH": "/usr/bin:/bin", "TERM": "dumb",
    ]
    environment["MULTISHELL_USER_ZDOTDIR"] = userZdotdir?.path
    let file = try await Detached.output(
      of: "/bin/zsh", ["-l", "-i", "-c", "print -r -- \"$HISTFILE\""],
      environment: environment, in: home, standardError: .discarded)
    return (file.trimmingCharacters(in: .newlines), home, integration)
  }

  private var systemRcSetsHistory: Bool {
    (try? String(contentsOfFile: "/etc/zshrc", encoding: .utf8))?.contains("HISTFILE=") == true
  }

  @Test func aTabsHistoryGoesWhereTheUsersOwnShellWouldPutIt() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let plain = try await historyFile()
    defer { try? FileManager.default.removeItem(at: plain.home.deletingLastPathComponent()) }
    #expect(!plain.file.hasPrefix(plain.integration.path), "\(plain.file)")
    if systemRcSetsHistory {
      #expect(plain.file == plain.home.appendingPathComponent(".zsh_history").path)
    }

    let root = try Scratch.directory("histfile-user")
    defer { try? FileManager.default.removeItem(at: root) }
    let own = root.appendingPathComponent("zdot", isDirectory: true)
    let relocated = try await historyFile(userZdotdir: own)
    defer { try? FileManager.default.removeItem(at: relocated.home.deletingLastPathComponent()) }
    if systemRcSetsHistory {
      #expect(relocated.file == own.appendingPathComponent(".zsh_history").path)
    }

    let chosen = try await historyFile(userZshrc: "HISTFILE=/elsewhere/history\n")
    defer { try? FileManager.default.removeItem(at: chosen.home.deletingLastPathComponent()) }
    #expect(chosen.file == "/elsewhere/history", "the user's own setting stands")
  }

  @Test func theSessionGetsZDOTDIROnlyWhenGeneratedAndTheShellIsZsh() throws {
    let dir = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: dir) }

    let zsh = ShellLaunch.zshIntegration(
      shellPath: "/bin/zsh", environment: ["ZDOTDIR": "/home/me/.zsh"], zshDirectory: dir)
    #expect(zsh["ZDOTDIR"] == dir.path)
    #expect(zsh["MULTISHELL_USER_ZDOTDIR"] == "/home/me/.zsh")

    let noUserZdotdir = ShellLaunch.zshIntegration(
      shellPath: "/bin/zsh", environment: [:], zshDirectory: dir)
    #expect(noUserZdotdir["ZDOTDIR"] == dir.path)
    #expect(noUserZdotdir["MULTISHELL_USER_ZDOTDIR"] == nil, "our files fall back to $HOME")

    #expect(
      ShellLaunch.zshIntegration(
        shellPath: "/bin/bash", environment: [:], zshDirectory: dir
      ).isEmpty,
      "bash is not injected this way")
    let chosen = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Shell",
      shellOverride: "/bin/bash")
    #expect(
      SessionEnvironment.variables(for: chosen, socket: URL(fileURLWithPath: "/s"))["ZDOTDIR"]
        == nil,
      "a tab whose chosen shell is bash gets no zsh integration whatever $SHELL is")
    let missing = dir.appendingPathComponent("gone", isDirectory: true)
    #expect(
      ShellLaunch.zshIntegration(
        shellPath: "/bin/zsh", environment: [:], zshDirectory: missing
      ).isEmpty,
      "nothing when the setting has not generated the directory")
  }

  /// libghostty sets `ZDOTDIR` to its own bootstrap and then applies the surface's
  /// variables on top, so ours would replace it and its integration would never load.
  @Test func theEnginesBootstrapIsEnteredFirstWhenItHasOne() throws {
    let ours = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: ours) }
    let bootstrap = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: bootstrap) }
    try Data().write(to: bootstrap.appendingPathComponent(".zshenv"))

    let chained = ShellLaunch.zshIntegration(
      shellPath: "/bin/zsh", environment: ["ZDOTDIR": "/u"], zshDirectory: ours,
      engineZshBootstrap: bootstrap)
    #expect(chained["ZDOTDIR"] == bootstrap.path)
    #expect(chained[ShellLaunch.ghosttyZdotdirKey] == ours.path)
    #expect(chained["MULTISHELL_USER_ZDOTDIR"] == "/u", "and ours still chains to the user's")

    let empty = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: empty) }
    let unbootstrapped = ShellLaunch.zshIntegration(
      shellPath: "/bin/zsh", environment: [:], zshDirectory: ours, engineZshBootstrap: empty)
    #expect(unbootstrapped["ZDOTDIR"] == ours.path, "a bootstrap with no startup file is no chain")
    #expect(unbootstrapped[ShellLaunch.ghosttyZdotdirKey] == nil)
    #expect(
      ShellLaunch.zshIntegration(
        shellPath: "/bin/bash", environment: [:], zshDirectory: ours,
        engineZshBootstrap: bootstrap
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
