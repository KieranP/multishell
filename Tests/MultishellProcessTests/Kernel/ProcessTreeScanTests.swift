import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessTreeScanTests {
  @Test func eachChildsTreeHoldsItselfFirstAndEverythingUnderIt() async throws {
    let process = Process()
    let input = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "sleep 60 & read line; kill $!"]
    process.environment = Scratch.shellEnvironment
    process.standardInput = input
    try process.run()
    defer {
      try? input.fileHandleForWriting.close()
      process.waitUntilExit()
    }
    let ownPID = ProcessInfo.processInfo.processIdentifier
    func tree() -> ProcessTree? {
      ProcessTreeScan.childTrees(of: ownPID).first { $0.rootPID == process.processIdentifier }
    }

    try await waitUntil { tree()?.processes.count == 2 }

    let found = try #require(tree())
    #expect(found.processes.first?.pid == process.processIdentifier)
    #expect(found.processes.last?.name == "sleep")
    #expect(found.processes.first?.parentPID == ownPID)
    #expect(found.processes.last?.parentPID == process.processIdentifier)
    #expect(found.processes.allSatisfy { $0.footprint > 0 })
  }

  @Test func aPidNothingHoldsHasNoChildrenAndNoUsage() {
    #expect(ProcessTreeScan.childTrees(of: 999_999_999).isEmpty)
    #expect(ProcessTreeScan.usage(of: 999_999_999) == nil)
  }
}
