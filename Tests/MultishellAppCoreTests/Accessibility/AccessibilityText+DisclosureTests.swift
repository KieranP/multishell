import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextDisclosureTests {
  @Test func anOpenSectionIsExpandedAndAShutOneCollapsed() {
    #expect(AccessibilityText.disclosure(isExpanded: true) == "expanded")
    #expect(AccessibilityText.disclosure(isExpanded: false) == "collapsed")
  }
}
