import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct StateDotKindTests {
  @Test func everyStateHasAShapeOfItsOwn() {
    let kinds = SessionState.allCases.map(StateDotKind.init)
    #expect(Set(kinds).count == SessionState.allCases.count)
  }

  @Test func doneFillsAndIdleIsTheEmptyRing() {
    #expect(StateDotKind(.done) == .filled)
    #expect(StateDotKind(.idle) == .hollowRing)
  }
}
