import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessAncestryTests {
  @Test func aProcessThatIsNotAShellIsItsOwnReportingProcess() {
    // The walk through real shells is covered end to end in the helper's
    // tests, where two `sh -c` layers stand between it and the runner.
    let me = ProcessInfo.processInfo.processIdentifier
    #expect(ProcessAncestry.reportingProcess(startingAt: me) == me)
  }

  /// From a prompt in one of the app's own tabs nothing between the shell
  /// and the app is a program, and the app is not what the state is about.
  @Test func theWalkStopsShortOfTheAppAndNamesTheShellUnderIt() throws {
    let shell = Process()
    shell.executableURL = URL(fileURLWithPath: "/bin/sh")
    shell.arguments = ["-c", "read line"]
    shell.standardInput = Pipe()
    try shell.run()
    defer { shell.terminate() }
    let me = ProcessInfo.processInfo.processIdentifier
    let under = shell.processIdentifier
    #expect(ProcessAncestry.reportingProcess(startingAt: under) == me, "the walk as it was")
    #expect(ProcessAncestry.reportingProcess(startingAt: under, stoppingAt: me) == under)
  }

  /// Failed once in a full run with the marked child unlisted, for a reason
  /// nobody has seen again; the answer is waited for rather than read once.
  @Test func childrenAreFoundByAWordOfTheirCommandLine() async throws {
    func waiting(_ script: String) throws -> Process {
      let shell = Process()
      shell.executableURL = URL(fileURLWithPath: "/bin/sh")
      shell.arguments = ["-c", script]
      shell.standardInput = Pipe()
      try shell.run()
      return shell
    }
    let marked = try waiting("read line # /shell-snapshots/snapshot-test")
    let plain = try waiting("read line")
    defer {
      marked.terminate()
      plain.terminate()
    }
    let me = ProcessInfo.processInfo.processIdentifier
    func found() -> [Int32] {
      ProcessAncestry.children(of: me, whoseArgumentsContain: "/shell-snapshots/")
    }

    try await waitUntil { found().contains(marked.processIdentifier) }

    #expect(found().contains(marked.processIdentifier))
    #expect(!found().contains(plain.processIdentifier))
    #expect(ProcessAncestry.children(of: 999_999_999, whoseArgumentsContain: "x").isEmpty)
  }
}
