import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct RunOnDispatchTests {
  @Test func moreBlockedWorkThanCoresStillLeavesATaskFreeToReleaseIt() async {
    let blockers = ProcessInfo.processInfo.activeProcessorCount + 1
    let gate = DispatchSemaphore(value: 0)
    let entered = Recorder<String>()

    let released = await withTaskGroup(of: Bool.self) { group in
      for _ in 0..<blockers {
        group.addTask {
          await runOnDispatch {
            entered.record("entered")
            return gate.wait(timeout: .now() + 10) == .success
          }
        }
      }
      group.addTask {
        try? await waitUntil { entered.received.count >= blockers }
        for _ in 0..<blockers { gate.signal() }
        return true
      }
      return await group.reduce(into: 0) { count, success in count += success ? 1 : 0 }
    }

    #expect(released == blockers + 1)
  }

  @Test func throwingWorkRethrowsItsErrorToTheCaller() async {
    struct Refused: Error {}
    await #expect(throws: Refused.self) {
      try await runOnDispatch { () throws -> Int in throw Refused() }
    }
  }
}
