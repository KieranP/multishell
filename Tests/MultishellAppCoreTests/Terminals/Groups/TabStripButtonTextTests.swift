import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct TabStripButtonTextTests {
  @Test func onlyTheFocusedGroupsSplitButtonsNameTheKeystroke() {
    let right = ShortcutCommand.splitRight.defaultCombination
    let down = ShortcutCommand.splitDown.defaultCombination
    #expect(
      TabStripButtonText.splitHelp(.horizontal, isFocusedGroup: true, keys: right)
        == "Split Right (⌘D)"
    )
    #expect(
      TabStripButtonText.splitHelp(.vertical, isFocusedGroup: true, keys: down)
        == "Split Down (⇧⌘D)"
    )
    #expect(
      TabStripButtonText.splitHelp(.horizontal, isFocusedGroup: false, keys: right)
        == "Split Right in This Group"
    )
    #expect(
      TabStripButtonText.splitHelp(.vertical, isFocusedGroup: false, keys: down)
        == "Split Down in This Group"
    )
  }

  @Test func aSplitWithChangedKeysNamesThemAndOneWithNoneNamesNothing() {
    let changed = KeyCombination(.character("\\"), .command)
    #expect(
      TabStripButtonText.splitHelp(.horizontal, isFocusedGroup: true, keys: changed)
        == "Split Right (⌘\\)"
    )
    #expect(
      TabStripButtonText.splitHelp(.vertical, isFocusedGroup: true, keys: nil) == "Split Down"
    )
  }

  @Test func eachSplitButtonNamesItsOwnCommandsKeys() {
    #expect(TabStripButtonText.splitCommand(.horizontal) == .splitRight)
    #expect(TabStripButtonText.splitCommand(.vertical) == .splitDown)
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
