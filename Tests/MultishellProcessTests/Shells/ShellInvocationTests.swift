import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

struct ShellInvocationTests {
  @Test func onlyKnownShellsGetTheInteractiveLoginFormOthersFallBackToSh() {
    #expect(ShellInvocation.forCommandLine(inShellAt: "/bin/zsh").arguments == ["-l", "-i", "-c"])
    #expect(ShellInvocation.forCommandLine(inShellAt: "/bin/zsh").executable.path == "/bin/zsh")
    for odd in ["/usr/local/bin/nu", "/opt/homebrew/bin/xonsh", "/no/such/zsh", ""] {
      let fallback = ShellInvocation.forCommandLine(inShellAt: odd)
      #expect(fallback.executable.path == "/bin/sh", "\(odd)")
      #expect(fallback.arguments == ["-c"], "\(odd)")
    }
  }

  @Test func aDirectoryNamedForAShellFallsBackToSh() throws {
    let root = try Scratch.directory("shell-directory")
    defer { Scratch.remove(root) }
    let directory = root.appendingPathComponent("zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let invocation = ShellInvocation.forCommandLine(inShellAt: directory.path)

    #expect(invocation.executable.path == "/bin/sh")
    #expect(invocation.arguments == ["-c"])
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/tcsh")))
  func theCshFamilyIsNotGivenTheLoginFlagItRefusesBesideC() async throws {
    #expect(ShellInvocation.forCommandLine(inShellAt: "/bin/tcsh").arguments == ["-i", "-c"])
    #expect(ShellInvocation.forCommandLine(inShellAt: "/bin/csh").arguments == ["-i", "-c"])
    let shell = try ScratchShell("/bin/tcsh")
    defer { shell.tearDown() }
    let home = shell.home

    let output = try await ShellCommand.runScript(
      "printf ok",
      in: home,
      shellPath: shell.path,
      environment: ["HOME": home.path],
    )

    #expect(output == "ok")
  }
}
