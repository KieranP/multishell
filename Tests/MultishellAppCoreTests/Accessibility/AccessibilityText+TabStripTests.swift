import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite
struct AccessibilityTextTabStripTests {
  @Test func aTabSaysWhetherItIsShownAndSplitAndWhichAgentItRuns() {
    #expect(
      AccessibilityText.tab(
        title: "zsh",
        isShown: true,
        isSplit: true,
        state: .done,
        agentName: nil,
      )
        == "zsh, tab, selected, split, Done"
    )
    #expect(
      AccessibilityText.tab(
        title: "claude",
        isShown: false,
        isSplit: false,
        state: nil,
        agentName: "Claude Code",
      )
        == "claude, tab, Claude Code, agent",
      "the mark is drawn, so it is said",
    )
    #expect(
      AccessibilityText.tab(
        title: "Claude Code",
        isShown: false,
        isSplit: false,
        state: nil,
        agentName: "Claude Code",
      )
        == "Claude Code, tab",
      "and not twice where the title is already the agent's name",
    )
  }

  /// A worktree with one group has nothing to tell apart, so its strip
  /// says nothing rather than "group 1 of 1" before every tab.
  @Test func aGroupOfTabsNamesItselfOnlyWhereThereAreSeveral() {
    #expect(AccessibilityText.tabGroup(position: 1, of: 1, isFocused: true).isEmpty)
    #expect(
      AccessibilityText.tabGroup(position: 2, of: 3, isFocused: true)
        == "Tab group 2 of 3, focused"
    )
    #expect(AccessibilityText.tabGroup(position: 1, of: 2, isFocused: false) == "Tab group 1 of 2")
  }

  @Test func aDropBandSaysWhichSideTheNewGroupGoes() {
    #expect(AccessibilityText.newTabGroupBand(.before) == "New tab group left")
    #expect(AccessibilityText.newTabGroupBand(.after) == "New tab group right")
  }
}
