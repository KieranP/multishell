import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct KernelProcessTableTests {
  @Test func theParentAndNameOfThisProcessAreKnown() {
    let ownPID = ProcessInfo.processInfo.processIdentifier
    #expect(KernelProcessTable.parent(of: ownPID) == getppid())
    #expect(KernelProcessTable.name(of: ownPID)?.isEmpty == false)
  }

  @Test func launchdIsKnownAndAPidNothingHoldsIsNot() {
    #expect(KernelProcessTable.name(of: 1) != nil)
    #expect(KernelProcessTable.name(of: 999_999_999) == nil)
    #expect(KernelProcessTable.parent(of: 999_999_999) == nil)
  }

  /// Failed once in a full run with the marked child unlisted, for a reason
  /// nobody has seen again; the answer is waited for rather than read once.
  @Test func childrenAreFoundByAWordOfTheirCommandLine() async throws {
    let marked = try WaitingShell(marker: "/shell-snapshots/snapshot-test")
    let plain = try WaitingShell()
    defer {
      marked.terminate()
      plain.terminate()
    }
    let ownPID = ProcessInfo.processInfo.processIdentifier
    func found() -> [Int32] {
      KernelProcessTable.children(of: ownPID, whoseArgumentsContain: "/shell-snapshots/")
    }

    try await waitUntil { found().contains(marked.pid) }

    #expect(found().contains(marked.pid))
    #expect(!found().contains(plain.pid))
    #expect(KernelProcessTable.children(of: 999_999_999, whoseArgumentsContain: "x").isEmpty)
  }
}
