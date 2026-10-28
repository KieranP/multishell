import Foundation
import Testing

@testable import MultishellCore

@Suite
struct HeldWriteTests {
  private static func block(until gate: DispatchSemaphore) {
    _ = gate.wait(timeout: .now() + 30)
  }

  @Test func aWriteIsHeldWhileEveryPoolThreadIsBlocked() {
    let blockers = ProcessInfo.processInfo.activeProcessorCount
    let gate = DispatchSemaphore(value: 0)
    for _ in 0..<blockers {
      Task { Self.block(until: gate) }
    }
    defer { for _ in 0..<blockers { gate.signal() } }

    let made = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)
    Thread {
      let held = HeldWrite(order: SaveOrder())
      made.signal()
      done.wait()
      held.release()
    }.start()
    defer { done.signal() }

    #expect(made.wait(timeout: .now() + 10) == .success)
  }
}
