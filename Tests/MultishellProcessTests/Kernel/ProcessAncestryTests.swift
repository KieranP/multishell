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
    #expect(ProcessAncestry.reportingPID(startingAt: me) == me)
  }

  /// From a prompt in one of the app's own tabs nothing between the shell
  /// and the app is a program, and the app is not what the state is about.
  @Test func theWalkStopsShortOfTheAppAndNamesTheShellUnderIt() throws {
    let shell = try WaitingShell()
    defer { shell.end() }
    let me = ProcessInfo.processInfo.processIdentifier
    let under = shell.pid
    #expect(ProcessAncestry.reportingPID(startingAt: under) == me, "the walk as it was")
    #expect(ProcessAncestry.reportingPID(startingAt: under, stoppingAt: me) == under)
  }

  /// Failed once in a full run with the marked child unlisted, for a reason
  /// nobody has seen again; the answer is waited for rather than read once.
  @Test func childrenAreFoundByAWordOfTheirCommandLine() async throws {
    let marked = try WaitingShell(marker: "/shell-snapshots/snapshot-test")
    let plain = try WaitingShell()
    defer {
      marked.end()
      plain.end()
    }
    let me = ProcessInfo.processInfo.processIdentifier
    func found() -> [Int32] {
      ProcessAncestry.children(of: me, whoseArgumentsContain: "/shell-snapshots/")
    }

    try await waitUntil { found().contains(marked.pid) }

    #expect(found().contains(marked.pid))
    #expect(!found().contains(plain.pid))
    #expect(ProcessAncestry.children(of: 999_999_999, whoseArgumentsContain: "x").isEmpty)
  }
}
