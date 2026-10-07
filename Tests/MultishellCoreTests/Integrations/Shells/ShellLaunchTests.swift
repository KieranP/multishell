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
