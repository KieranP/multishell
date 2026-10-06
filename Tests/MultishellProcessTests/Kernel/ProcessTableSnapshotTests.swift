import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessTableSnapshotTests {
  @Test func oneReadAnswersAsTheReadsPerPidDo() async throws {
    let shell = try WaitingShell()
    defer { shell.end() }
    let me = ProcessInfo.processInfo.processIdentifier
    try await waitUntil { KernelProcessTable.name(of: shell.pid) != nil }
    let table = ProcessTableSnapshot.take()

    #expect(table.children(of: me).contains(shell.pid))
    // Not the shell's name: macOS's /bin/sh re-execs as bash between two reads.
    #expect(table.name(of: me) == KernelProcessTable.name(of: me))
    #expect(table.terminalDevice(of: me) == KernelProcessTable.terminalDevice(of: me))
  }

  @Test func aPidNothingHoldsHasNoChildrenNameOrTerminal() {
    let table = ProcessTableSnapshot.take()
    #expect(table.children(of: 999_999_999).isEmpty)
    #expect(table.name(of: 999_999_999) == nil)
    #expect(table.terminalDevice(of: 999_999_999) == nil)
  }
}
