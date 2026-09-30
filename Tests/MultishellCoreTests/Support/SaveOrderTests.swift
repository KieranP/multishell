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
