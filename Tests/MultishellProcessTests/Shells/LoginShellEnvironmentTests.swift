import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct LoginShellEnvironmentTests {
  @Test func nulSeparatedOutputParsesIncludingValuesWithNewlinesAndEquals() {
    let text = "PATH=/opt/homebrew/bin:/usr/bin\0MULTI=line one\nline two\0EQ=a=b=c\0BROKEN\0"
    let parsed = LoginShellEnvironment.parse(nulSeparated: text)
    #expect(parsed["PATH"] == "/opt/homebrew/bin:/usr/bin")
    #expect(parsed["MULTI"] == "line one\nline two")
    #expect(parsed["EQ"] == "a=b=c")
    #expect(parsed["BROKEN"] == nil)
    #expect(parsed.count == 3)
  }

  @Test func anRcFileGreetingBeforeTheFirstEntryDoesNotBecomeAKey() {
    let text = "Welcome back!\nHave a nice day\nHOME=/Users/dev\0PATH=/bin\0"
    let parsed = LoginShellEnvironment.parse(nulSeparated: text)
    #expect(parsed["HOME"] == "/Users/dev")
    #expect(parsed["PATH"] == "/bin")
    #expect(parsed.count == 2)
  }

  @Test func aGreetingHoldingAnEqualsSignStillLeavesTheFirstEntryItsKey() {
    let text = "==== welcome ====\nPATH=/bin\0HOME=/Users/dev\0"
    let parsed = LoginShellEnvironment.parse(nulSeparated: text)
    #expect(parsed["PATH"] == "/bin", "the first `=` is the banner's, the key is after the newline")
    #expect(parsed["HOME"] == "/Users/dev")
    #expect(parsed.count == 2)
  }

  @Test func theCaptureLeavesAHistoryFileItsEnvironmentNamesAlone() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/bash") else { return }
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let history = home.appendingPathComponent("zsh_history")
    let lines = (1...600).map { ": 1700000000:0;command \($0)\n" }.joined()
    try lines.write(to: history, atomically: true, encoding: .utf8)
    try "HISTFILESIZE=10\n".write(
      to: home.appendingPathComponent(".bash_profile"), atomically: true, encoding: .utf8)

    _ = await LoginShellEnvironment.capture(
      shellPath: "/bin/bash", home: home, inherited: ["HISTFILE": history.path])

    #expect(try String(contentsOf: history, encoding: .utf8) == lines)
  }

  /// macOS `/etc/zshrc` sets HISTFILE again after the empty one is inherited.
  @Test func theCaptureLeavesZshHistoryAloneThoughEtcZshrcNamesIt() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    let history = home.appendingPathComponent(".zsh_history")
    let lines = (1...600).map { ": 1700000000:0;command \($0)\n" }.joined()
    try lines.write(to: history, atomically: true, encoding: .utf8)
    try "HISTFILE=\(history.path)\nSAVEHIST=10\nsetopt share_history inc_append_history\n"
      .write(to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    _ = await LoginShellEnvironment.capture(shellPath: "/bin/zsh", home: home)

    #expect(try String(contentsOf: history, encoding: .utf8) == lines)
  }

  @Test func aLoginShellAnswersWithThePathItsOwnRcFilesBuilt() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    try "export PATH=/opt/marker/bin:$PATH\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let environment = await LoginShellEnvironment.capture(shellPath: "/bin/zsh", home: home)

    #expect(environment.path?.hasPrefix("/opt/marker/bin:") == true, "\(environment)")
    #expect(environment.source == .loginShell(URL(fileURLWithPath: "/bin/zsh")))
  }

  @Test func aShellCutOffByTheTimeoutSaysSoRatherThanNamingItsSignal() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    try "sleep 30\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let environment = await LoginShellEnvironment.capture(
      timeout: .milliseconds(300), shellPath: "/bin/zsh", home: home)

    #expect(environment.source == .processFallback(reason: "timed out after 0.3 seconds"))
  }

  @Test func aGreetingShapedLikeAnAssignmentIsNotTakenForAVariable() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { Scratch.remove(home) }
    try "printf 'motd=welcome back'\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let environment = await LoginShellEnvironment.capture(shellPath: "/bin/zsh", home: home)

    #expect(environment.variables["motd"] == nil)
    #expect(environment.variables["HOME"] == home.path)
    #expect(environment.path != nil)
  }

  @Test func onlyWhatFollowsTheMarkerIsTheEnvironment() {
    let text = "motd=hi\n\(LoginShellEnvironment.startMarker)\nHOME=/u\0PATH=/bin\0"

    #expect(LoginShellEnvironment.parse(nulSeparated: text) == ["HOME": "/u", "PATH": "/bin"])
  }

  @Test func aShellThatHangsFallsBackWithinTheTimeout() async throws {
    // A runner whose "shell" never exits: the fallback must arrive, and
    // soon. Stand-in via a timeout on a real sleeping child.
    let started = ContinuousClock.now
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "sleep 30"], in: URL(fileURLWithPath: "/tmp"),
      timeout: .milliseconds(300))
    let elapsed = ContinuousClock.now - started
    #expect(!output.succeeded)
    // Ten against the child's thirty: the two answers are the timeout
    // firing and it not firing at all, and no runner is between them.
    #expect(elapsed < .seconds(10), "took \(elapsed)")
  }
}
