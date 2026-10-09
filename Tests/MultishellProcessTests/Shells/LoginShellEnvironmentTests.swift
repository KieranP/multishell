import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct LoginShellEnvironmentTests {
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func theCaptureLeavesAHistoryFileItsEnvironmentNamesAlone() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let history = home.appendingPathComponent("zsh_history")
    let lines = LongHistory.lines
    try lines.write(to: history, atomically: true, encoding: .utf8)
    try "HISTFILESIZE=10\n".write(
      to: home.appendingPathComponent(".bash_profile"),
      atomically: true,
      encoding: .utf8,
    )

    _ = await LoginShellEnvironment.capture(
      shellPath: "/bin/bash",
      home: home,
      extraEnvironment: ["HISTFILE": history.path],
    )

    #expect(try String(contentsOf: history, encoding: .utf8) == lines)
  }

  /// macOS `/etc/zshrc` sets HISTFILE again after the empty one is inherited.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func theCaptureLeavesZshHistoryAloneThoughEtcZshrcNamesIt() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let history = home.appendingPathComponent(".zsh_history")
    let lines = LongHistory.lines
    try lines.write(to: history, atomically: true, encoding: .utf8)
    try "HISTFILE=\(history.path)\nSAVEHIST=10\nsetopt share_history inc_append_history\n"
      .write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    _ = await LoginShellEnvironment.capture(shellPath: "/bin/zsh", home: home)

    #expect(try String(contentsOf: history, encoding: .utf8) == lines)
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aLoginShellAnswersWithThePathItsOwnRcFilesBuilt() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    try "export PATH=/opt/marker/bin:$PATH\n".write(
      to: home.appendingPathComponent(".zshrc"),
      atomically: true,
      encoding: .utf8,
    )

    let environment = await LoginShellEnvironment.capture(shellPath: "/bin/zsh", home: home)

    #expect(environment.path?.hasPrefix("/opt/marker/bin:") == true, "\(environment)")
    #expect(environment.source == .loginShell(URL(fileURLWithPath: "/bin/zsh")))
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aGreetingShapedLikeAnAssignmentIsNotTakenForAVariable() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    try "printf 'motd=welcome back'\n".write(
      to: home.appendingPathComponent(".zshrc"),
      atomically: true,
      encoding: .utf8,
    )

    let environment = await LoginShellEnvironment.capture(shellPath: "/bin/zsh", home: home)

    #expect(environment.variables["motd"] == nil)
    #expect(environment.variables["HOME"] == home.path)
    #expect(environment.path != nil)
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aShellThatHangsFallsBackToTheAppsOwnEnvironmentAndSaysItTimedOut() async throws {
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    try "sleep 30\n".write(
      to: home.appendingPathComponent(".zshrc"),
      atomically: true,
      encoding: .utf8,
    )

    let started = ContinuousClock.now
    let environment = await LoginShellEnvironment.capture(
      shellPath: "/bin/zsh",
      timeout: .milliseconds(300),
      home: home,
    )
    let elapsed = ContinuousClock.now - started

    #expect(environment.variables == ProcessInfo.processInfo.environment)
    #expect(
      environment.source == .processFallback(reason: "timed out after 0.3 seconds"),
      "the timeout said as such, not as the signal that ended the shell",
    )
    // Ten against the rc file's thirty: the timeout firing, or not at all.
    #expect(elapsed < .seconds(10), "took \(elapsed)")
  }
}
