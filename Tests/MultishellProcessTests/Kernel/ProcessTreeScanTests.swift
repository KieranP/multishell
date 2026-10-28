import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessTreeScanTests {
  @Test func eachChildsTreeHoldsItselfFirstAndEverythingUnderIt() async throws {
    let shell = try WaitingShell(backgrounding: "sleep 60")
    defer { try? shell.finish() }
    let ownPID = ProcessInfo.processInfo.processIdentifier
    func tree() -> ProcessTree? {
      ProcessTreeScan.childTrees(of: ownPID).first { $0.rootPID == shell.pid }
    }

    try await waitUntil { tree()?.processes.count == 2 }

    let found = try #require(tree())
    #expect(found.processes.first?.pid == shell.pid)
    #expect(found.processes.last?.name == "sleep")
    #expect(found.processes.first?.parentPID == ownPID)
    #expect(found.processes.last?.parentPID == shell.pid)
    #expect(found.processes.allSatisfy { $0.footprint > 0 })
  }

  @Test func aPidNothingHoldsHasNoChildrenAndNoUsage() {
    let pid = deadPID()
    #expect(ProcessTreeScan.childTrees(of: pid).isEmpty)
    #expect(ProcessTreeScan.usage(of: pid) == nil)
  }
}
