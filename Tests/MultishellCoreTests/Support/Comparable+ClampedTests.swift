import Testing

@testable import MultishellCore

@Suite
struct ComparableClampedTests {
  @Test func clampedHoldsAValueInsideTheRange() {
    #expect(5.clamped(to: 0...3) == 3)
    #expect((-1).clamped(to: 0...3) == 0)
    #expect(2.5.clamped(to: 0...3) == 2.5)
  }
}
