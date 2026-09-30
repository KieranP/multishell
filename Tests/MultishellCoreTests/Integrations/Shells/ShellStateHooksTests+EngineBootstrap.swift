import Foundation
import Testing

@testable import MultishellCore

/// A zsh under Ghostty enters the engine's bootstrap first, which chains on to ours.
extension ShellStateHooksTests {
  /// libghostty's zsh integration loads only through its bootstrap `.zshenv`, and the
  /// engine applies a surface's variables after that, so the session names both.
  @Test func aFreshTabEntersTheEnginesBootstrapWhichChainsOnToOurs() async throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let bootstrap = try files.writeEngineBootstrap()
    var environment = files.environment(termProgram: "ghostty")
    environment.merge(
      ShellLaunch.zshEnvironment(
        forShell: zsh, environment: [:], zshDirectory: files.zshDirectory,
        engineZshBootstrap: bootstrap)
    ) { _, new in new }
    #expect(environment["ZDOTDIR"] == bootstrap.path)

    let output = try await interactiveShell(zsh, arguments: ["-i"], environment: environment)
    #expect(output.contains(Marks.input), "the engine's mark, so the chain reached its file")
    #expect(output.contains(Marks.claim), "and ours, so the chain came on to our file")
    let plain = try #require(output.range(of: Marks.plainStart, options: .backwards))
    let claim = try #require(output.range(of: Marks.claim, options: .backwards))
    #expect(plain.lowerBound < claim.lowerBound, "the claim still lands last")
  }

  /// The shell after an exited agent is started by a fragment, not the session's
  /// environment, so it finds both through the variable the engine leaves in every child.
  @Test func theShellAfterAnAgentEntersTheEnginesBootstrapUnderGhosttyOnly() async throws {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    _ = try files.writeEngineBootstrap()
    // A tab is a pty, so the shell it starts is interactive; a pipe is not.
    let exec = ShellLaunch.execCommandLine(
      forShell: zsh, zshDirectory: files.zshDirectory, bashInit: files.bashInit
    ).replacingOccurrences(of: "exec \(zsh) -l", with: "exec \(zsh) -l -i")
    #expect(exec.contains(files.engineResources.path) == false, "found at run time, not baked in")

    var ghostty = files.environment(termProgram: "ghostty")
    ghostty["GHOSTTY_RESOURCES_DIR"] = files.engineResources.path
    let chained = try await interactiveShell(
      "/bin/sh", arguments: ["-c", "true; \(exec)"], environment: ghostty)
    #expect(chained.contains(Marks.plainStart), "the engine's file was entered")
    #expect(chained.contains(Marks.claim), "and ours after it")

    // The login shell running the line may not be POSIX; csh is the one at hand.
    if FileManager.default.isExecutableFile(atPath: "/bin/csh") {
      let fromCsh = try await interactiveShell(
        "/bin/csh", arguments: ["-c", "true; \(exec)"], environment: ghostty)
      #expect(fromCsh.contains(Marks.plainStart), "the fragment reads the same to csh")
      #expect(fromCsh.contains(Marks.claim))
    }

    var elsewhere = files.environment(termProgram: nil)
    elsewhere[SessionEnvironment.sessionKey] = "after-agent"
    elsewhere[SessionEnvironment.socketKey] = "/nonexistent.sock"
    let plain = try await interactiveShell(
      "/bin/sh", arguments: ["-c", "true; \(exec)"], environment: elsewhere,
      input: "(( $+functions[_multishell_precmd] )) && printf 'HOOKS%s\\n' OK\nexit\n")
    #expect(plain.contains(Marks.plainStart) == false, "no engine, no bootstrap")
    #expect(plain.contains(Marks.claim) == false, "and no claim outside Ghostty")
    #expect(plain.contains("HOOKSOK"), "but ours was entered directly")
  }
}
