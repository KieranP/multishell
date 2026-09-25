import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension ShellLaunchTests {
  private func directoryThatExists() throws -> URL {
    let url = try Scratch.directory("zdotdir")
    return url
  }

  @Test func theSessionGetsZDOTDIROnlyWhenGeneratedAndTheShellIsZsh() throws {
    let dir = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: dir) }

    let zsh = ShellLaunch.zshEnvironment(
      forShell: "/bin/zsh", environment: ["ZDOTDIR": "/home/me/.zsh"], zshDirectory: dir)
    #expect(zsh["ZDOTDIR"] == dir.path)
    #expect(zsh["MULTISHELL_USER_ZDOTDIR"] == "/home/me/.zsh")

    let noUserZdotdir = ShellLaunch.zshEnvironment(
      forShell: "/bin/zsh", environment: [:], zshDirectory: dir)
    #expect(noUserZdotdir["ZDOTDIR"] == dir.path)
    #expect(noUserZdotdir["MULTISHELL_USER_ZDOTDIR"] == nil, "our files fall back to $HOME")

    #expect(
      ShellLaunch.zshEnvironment(
        forShell: "/bin/bash", environment: [:], zshDirectory: dir
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
      ShellLaunch.zshEnvironment(
        forShell: "/bin/zsh", environment: [:], zshDirectory: missing
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

    let chained = ShellLaunch.zshEnvironment(
      forShell: "/bin/zsh", environment: ["ZDOTDIR": "/u"], zshDirectory: ours,
      engineZshBootstrap: bootstrap)
    #expect(chained["ZDOTDIR"] == bootstrap.path)
    #expect(chained[ShellLaunch.ghosttyZdotdirKey] == ours.path)
    #expect(chained["MULTISHELL_USER_ZDOTDIR"] == "/u", "and ours still chains to the user's")

    let empty = try directoryThatExists()
    defer { try? FileManager.default.removeItem(at: empty) }
    let unbootstrapped = ShellLaunch.zshEnvironment(
      forShell: "/bin/zsh", environment: [:], zshDirectory: ours, engineZshBootstrap: empty)
    #expect(unbootstrapped["ZDOTDIR"] == ours.path, "a bootstrap with no startup file is no chain")
    #expect(unbootstrapped[ShellLaunch.ghosttyZdotdirKey] == nil)
    #expect(
      ShellLaunch.zshEnvironment(
        forShell: "/bin/bash", environment: [:], zshDirectory: ours,
        engineZshBootstrap: bootstrap
      ).isEmpty, "bash is not chained either way")
  }
}
