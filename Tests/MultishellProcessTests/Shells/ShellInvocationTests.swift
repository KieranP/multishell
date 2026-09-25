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

  @Test func theCshFamilyIsNotGivenTheLoginFlagItRefusesBesideC() async throws {
    #expect(ShellInvocation.userShell(at: "/bin/tcsh").arguments == ["-i", "-c"])
    #expect(ShellInvocation.userShell(at: "/bin/csh").arguments == ["-i", "-c"])
    guard FileManager.default.isExecutableFile(atPath: "/bin/tcsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }

    let out = try await ShellCommand.runScript(
      "printf ok", in: home, environment: ["HOME": home.path], shellPath: "/bin/tcsh")

    #expect(out == "ok")
  }
}
