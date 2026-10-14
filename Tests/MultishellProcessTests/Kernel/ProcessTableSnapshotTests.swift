import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessTableSnapshotTests {
  @Test func oneReadAnswersAsTheReadsPerPidDo() async throws {
    let shell = try WaitingShell()
    defer { shell.terminate() }
    let ownPID = ProcessInfo.processInfo.processIdentifier
    try await waitUntil { KernelProcessTable.name(of: shell.pid) != nil }
    let table = ProcessTableSnapshot.take()

    #expect(table.children(of: ownPID).contains(shell.pid))
    // Not the shell's name: macOS's /bin/sh re-execs as bash between two reads.
    #expect(table.name(of: ownPID) == KernelProcessTable.name(of: ownPID))
    #expect(
      table.terminalDevice(of: ownPID)
        == KernelProcessTable.record(of: ownPID).flatMap(KernelProcessTable.terminalDevice(in:))
    )
  }

  @Test func aPidNothingHoldsHasNoChildrenNameOrTerminal() {
    let table = ProcessTableSnapshot.take()
    let pid = deadPID()
    #expect(table.children(of: pid).isEmpty)
    #expect(table.name(of: pid) == nil)
    #expect(table.terminalDevice(of: pid) == nil)
  }
}
