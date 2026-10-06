import Foundation
import TestScratch
import Testing

@testable import MultishellCore

extension ShellLaunchTests {
  @Test func theSessionGetsZDOTDIROnlyWhenGeneratedAndTheShellIsZsh() throws {
    let zshDirectory = try Scratch.directory("zdotdir")
    defer { Scratch.remove(zshDirectory) }

    let zsh = ShellLaunch.zshEnvironment(
      forShell: "/bin/zsh", environment: ["ZDOTDIR": "/home/me/.zsh"], zshDirectory: zshDirectory)
    #expect(zsh["ZDOTDIR"] == zshDirectory.path)
    #expect(zsh["MULTISHELL_USER_ZDOTDIR"] == "/home/me/.zsh")

    let noUserZdotdir = ShellLaunch.zshEnvironment(
      forShell: "/bin/zsh", environment: [:], zshDirectory: zshDirectory)
    #expect(noUserZdotdir["ZDOTDIR"] == zshDirectory.path)
    #expect(noUserZdotdir["MULTISHELL_USER_ZDOTDIR"] == nil, "our files fall back to $HOME")

    #expect(
      ShellLaunch.zshEnvironment(
        forShell: "/bin/bash", environment: [:], zshDirectory: zshDirectory
      ).isEmpty,
      "bash is not injected this way")
    let chosen = TerminalSession(
      worktreeID: "/w", workingDirectory: URL(fileURLWithPath: "/w"), title: "Shell",
      shellOverride: "/bin/bash")
    #expect(
      SessionEnvironment.variables(for: chosen, socket: URL(fileURLWithPath: "/s"))["ZDOTDIR"]
        == nil,
      "a tab whose chosen shell is bash gets no zsh integration whatever $SHELL is")
    let missing = zshDirectory.appendingPathComponent("gone", isDirectory: true)
    #expect(
      ShellLaunch.zshEnvironment(
        forShell: "/bin/zsh", environment: [:], zshDirectory: missing
      ).isEmpty,
      "nothing when the setting has not generated the directory")
  }
}
