import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
struct OffMainTests {
  @Test func moreBlockedWorkThanCoresStillLeavesATaskFreeToReleaseIt() async {
    let blockers = ProcessInfo.processInfo.activeProcessorCount + 1
    let gate = DispatchSemaphore(value: 0)
    let entered = LineRecorder()

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
        while entered.received.count < blockers {
          try? await Task.sleep(for: .milliseconds(10))
        }
        for _ in 0..<blockers { gate.signal() }
        return true
      }
      return await group.reduce(into: 0) { count, success in count += success ? 1 : 0 }
    }

    #expect(released == blockers + 1)
  }
}
