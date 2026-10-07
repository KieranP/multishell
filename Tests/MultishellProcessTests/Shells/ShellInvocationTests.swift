import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

struct ShellInvocationTests {
  @Test func onlyKnownShellsGetTheInteractiveLoginFormOthersFallBackToSh() {
    #expect(ShellInvocation.userShell(at: "/bin/zsh").arguments == ["-l", "-i", "-c"])
    #expect(ShellInvocation.userShell(at: "/bin/zsh").executable.path == "/bin/zsh")
    for odd in ["/usr/local/bin/nu", "/opt/homebrew/bin/xonsh", "/no/such/zsh", ""] {
      let fallback = ShellInvocation.userShell(at: odd)
      #expect(fallback.executable.path == "/bin/sh", "\(odd)")
      #expect(fallback.arguments == ["-c"], "\(odd)")
    }
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/tcsh")))
  func theCshFamilyIsNotGivenTheLoginFlagItRefusesBesideC() async throws {
    #expect(ShellInvocation.userShell(at: "/bin/tcsh").arguments == ["-i", "-c"])
    #expect(ShellInvocation.userShell(at: "/bin/csh").arguments == ["-i", "-c"])
    let shell = try ScratchShell("/bin/tcsh")
    defer { shell.tearDown() }
    let home = shell.home

    let output = try await ShellCommand.runScript(
      "printf ok", in: home, environment: ["HOME": home.path], shellPath: shell.path)

    #expect(output == "ok")
  }
}
