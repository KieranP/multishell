import Foundation
import Testing

@testable import MultishellCore

@Suite
struct SaveOrderTests {
  @Test func aTicketIsIssuedWhileAWriteIsStillLanding() {
    let order = SaveOrder()
    let held = HeldWrite(order: order)
    defer { held.release() }

    #expect(held.answers { _ = order.issue() })
  }

  @Test func whetherATicketLandedLastIsAnsweredWhileAWriteIsStillLanding() {
    let order = SaveOrder()
    let earlier = order.issue()
    order.land(earlier) {}
    let held = HeldWrite(order: order)
    defer { held.release() }

    #expect(held.answers { _ = order.isLastLanded(earlier) })
  }

  @Test func aTicketHasNotLandedLastWhileALaterWriteIsStillLanding() {
    let order = SaveOrder()
    let earlier = order.issue()
    order.land(earlier) {}
    let held = HeldWrite(order: order)
    defer { held.release() }

    #expect(!order.isLastLanded(earlier))
  }

  @Test func aTicketStillLandedLastWhenALaterWriteFails() {
    let order = SaveOrder()
    let earlier = order.issue()
    order.land(earlier) {}

    _ = try? order.land(order.issue()) { throw CocoaError(.fileWriteNoPermission) }

    #expect(order.isLastLanded(earlier))
  }
}

/// A write that stays inside `land` until released, on a thread of its own.
private final class HeldWrite: Sendable {
  private let entered = DispatchSemaphore(value: 0)
  private let released = DispatchSemaphore(value: 0)

  init(order: SaveOrder) {
    let ticket = order.issue()
    DispatchQueue.global().async { [entered, released] in
      order.land(ticket) {
        entered.signal()
        released.wait()
      }
    }
    entered.wait()
  }

  /// Whether `call` returns while the write is held. Held, the write never
  /// ends, so the bound only tells a wait from none.
  func answers(_ call: @escaping @Sendable () -> Void) -> Bool {
    let returned = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      call()
      returned.signal()
    }
    return returned.wait(timeout: .now() + 10) == .success
  }

  func release() {
    released.signal()
  }
}
