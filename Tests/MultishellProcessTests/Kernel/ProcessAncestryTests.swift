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
    defer { shell.terminate() }
    let me = ProcessInfo.processInfo.processIdentifier
    let under = shell.pid
    #expect(ProcessAncestry.reportingPID(startingAt: under) == me, "the walk as it was")
    #expect(ProcessAncestry.reportingPID(startingAt: under, stoppingAt: me) == under)
  }
}
