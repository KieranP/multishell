import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct OffMainTests {
  @Test func moreBlockedWorkThanCoresStillLeavesATaskFreeToReleaseIt() async {
    let blockers = ProcessInfo.processInfo.activeProcessorCount + 1
    let gate = DispatchSemaphore(value: 0)
    let entered = Recorder<String>()

    let released = await withTaskGroup(of: Bool.self) { group in
      for _ in 0..<blockers {
        group.addTask {
          await offMain {
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
}
