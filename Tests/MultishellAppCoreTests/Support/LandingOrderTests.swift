import Testing

@testable import MultishellAppCore

@Suite
struct LandingOrderTests {
  @Test func anOlderReadLandsUntilANewerOneHasLandedForItsKey() {
    var order = LandingOrder<String>()
    let older = order.begin()
    let newer = order.begin()
    let elsewhere = order.begin()

    let olderFirst = order.lands(older, for: "a")
    let newerAfter = order.lands(newer, for: "a")
    let olderAgain = order.lands(older, for: "a")
    let olderOnB = order.lands(older, for: "b")
    let newerOnB = order.lands(elsewhere, for: "b")

    #expect(olderFirst, "a later read merely begun does not stop it")
    #expect(newerAfter)
    #expect(!olderAgain)
    #expect(olderOnB, "each key is ordered on its own")
    #expect(newerOnB)
  }

  @Test func aForgottenKeyTakesAnyReadAgain() {
    var order = LandingOrder<String>()
    let older = order.begin()
    _ = order.lands(order.begin(), for: "a")

    order.forget("a")

    let lands = order.lands(older, for: "a")
    #expect(lands)
  }
}
