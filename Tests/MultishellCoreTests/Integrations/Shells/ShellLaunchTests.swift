import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct ShellLaunchTests {
  @Test func theExecAfterAnAgentCarriesTheIntegrationBackIn() throws {
    let bashInit = try Scratch.initFileThatExists()
    defer { Scratch.remove(bashInit) }
    let zshDirectory = try Scratch.directory("zdot")
    defer { Scratch.remove(zshDirectory) }
    let fishInit = try Scratch.initFileThatExists()
    defer { Scratch.remove(fishInit) }

    #expect(
      ShellLaunch.execArguments(
        forShell: "/bin/zsh",
        zshDirectory: zshDirectory,
        bashInit: bashInit,
        fishInit: fishInit,
      )
        == ["exec", "env", "ZDOTDIR=\(zshDirectory.path)", "/bin/zsh", "-l"]
    )
    #expect(
      ShellLaunch.execArguments(
        forShell: "/bin/bash",
        zshDirectory: zshDirectory,
        bashInit: bashInit,
        fishInit: fishInit,
      )
        == ["exec", "/bin/bash", "--init-file", bashInit.path, "-i"]
    )
    let missing = URL(fileURLWithPath: "/no/such")
    #expect(
      ShellLaunch.execArguments(
        forShell: "/bin/zsh",
        zshDirectory: missing,
        bashInit: missing,
        fishInit: missing,
      )
        == ["exec", "/bin/zsh", "-l"]
    )
    #expect(
      ShellLaunch.execArguments(
        forShell: "/usr/local/bin/fish",
        zshDirectory: zshDirectory,
        bashInit: bashInit,
        fishInit: fishInit,
      )
        == [
          "exec", "/usr/local/bin/fish", "-l", "-C",
          "source \(AnyShellQuoting.quote(fishInit.path))",
        ]
    )
    #expect(
      ShellLaunch.execArguments(
        forShell: "/usr/local/bin/fish",
        zshDirectory: missing,
        bashInit: missing,
        fishInit: missing,
      )
        == ["exec", "/usr/local/bin/fish", "-l"]
    )
  }

  /// The init file lives under Application Support, a path with a space in
  /// it, and `-C` hands fish a line it parses as its own.
  @Test(arguments: InstalledShells.only(InstalledShells.fishCandidates))
  func fishSourcesAnInitFileWhosePathHoldsASpaceAQuoteAndABackslash(fish: String) async throws {
    let directory = try Scratch.directory("fish init")
    defer { Scratch.remove(directory) }
    let fishInit = directory.appendingPathComponent("it's a \\ init.fish")
    try "echo multishell-init-ran\n".write(to: fishInit, atomically: true, encoding: .utf8)

    let arguments = ShellLaunch.fishInitArguments(forShell: fish, fishInit: fishInit)
    let output = try await Detached.output(
      of: fish,
      Array(arguments.dropFirst()) + ["-c", "true"],
      environment: Scratch.bareShellEnvironment(home: directory),
      in: directory,
    )

    #expect(output.contains("multishell-init-ran"), "\(output)")
  }
}
