import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct AccessibilityTextServicesTests {
  @Test func eachRunStatusIsSaidAsTheGlyphDrawsIt() {
    #expect(AccessibilityText.ciStatus(.cancelled) == "cancelled")
    #expect(AccessibilityText.ciStatus(.failed) == "failed")
    #expect(AccessibilityText.ciStatus(.onHold) == "on hold")
    #expect(AccessibilityText.ciStatus(.passed) == "passed")
    #expect(AccessibilityText.ciStatus(.running) == "running")
    #expect(AccessibilityText.ciStatus(.unknown) == "status unknown")
  }

  @Test func anEarlierRunSaysItsStatusThenWhetherItIsOpen() {
    #expect(AccessibilityText.ciStatus(.failed, isExpanded: false) == "failed, collapsed")
  }
}
