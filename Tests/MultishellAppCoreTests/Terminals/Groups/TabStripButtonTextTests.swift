import Testing

@testable import MultishellAppCore

@Suite
struct TabStripButtonTextTests {
  @Test func onlyTheFocusedGroupsSplitButtonsNameTheKeystroke() {
    #expect(TabStripButtonText.splitHelp(.horizontal, isFocusedGroup: true) == "Split Right (⌘D)")
    #expect(TabStripButtonText.splitHelp(.vertical, isFocusedGroup: true) == "Split Down (⇧⌘D)")
    #expect(
      TabStripButtonText.splitHelp(.horizontal, isFocusedGroup: false)
        == "Split Right in This Group")
    #expect(
      TabStripButtonText.splitHelp(.vertical, isFocusedGroup: false) == "Split Down in This Group")
  }

  @Test func anotherGroupsNewTabMenuSaysItOpensThere() {
    #expect(TabStripButtonText.newTabHelp(isFocusedGroup: true) == "New Tab")
    #expect(TabStripButtonText.newTabHelp(isFocusedGroup: false) == "New Tab in This Group")
  }

  @Test func aSplitButtonIsSpokenByItsDirectionAlone() {
    #expect(TabStripButtonText.splitLabel(.horizontal) == "Split Right")
    #expect(TabStripButtonText.splitLabel(.vertical) == "Split Down")
  }
}
