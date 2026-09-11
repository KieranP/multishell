import Foundation
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

  @Test func theUsersShellAnswersWithAPath() async {
    let environment = await LoginShellEnvironment.capture()
    #expect(environment.path?.isEmpty == false)
    if case .processFallback(let reason) = environment.source {
      Issue.record("fell back to the process environment: \(reason)")
    }
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

  @Test func executableLookupWalksTheGivenPathNotTheProcessOne() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-path-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fake = directory.appendingPathComponent("claude")
    try "#!/bin/sh\nexit 0\n".write(to: fake, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
    try "not executable".write(
      to: directory.appendingPathComponent("codex"), atomically: true, encoding: .utf8)

    let path = "/nowhere:\(directory.path):/bin"
    #expect(ExecutableLookup.find("claude", path: path)?.path == fake.path)
    #expect(ExecutableLookup.find("codex", path: path) == nil, "present but not executable")
    #expect(ExecutableLookup.find("sh", path: path) != nil)
    #expect(ExecutableLookup.find("claude", path: "/usr/bin") == nil)
  }
}

@Suite
struct ProcessAncestryTests {
  @Test func theParentAndNameOfThisProcessAreKnown() {
    let me = ProcessInfo.processInfo.processIdentifier
    #expect(ProcessAncestry.parent(of: me) == getppid())
    #expect(ProcessAncestry.name(of: me)?.isEmpty == false)
    #expect(ProcessAncestry.name(of: 1) != nil, "launchd or init")
    #expect(ProcessAncestry.parent(of: 999_999_999) == nil)
  }

  @Test func aProcessThatIsNotAShellIsItsOwnReportingProcess() {
    // The walk through real shells is covered end to end in the helper's
    // tests, where two `sh -c` layers stand between it and the runner.
    let me = ProcessInfo.processInfo.processIdentifier
    #expect(ProcessAncestry.reportingProcess(startingAt: me) == me)
  }
}
