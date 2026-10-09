import MultishellCore
import Testing

@testable import MultishellAppCore

/// Every pane's find is its own and the search the engine's, so what is tested
/// is which panes have a bar and what each pane's engine was told.
@Suite @MainActor
struct AppModelFindTests {
  @Test func findOpensOnTheFocusedPaneOfTheShownTabWithoutSearchingYet() {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = focusedPane(of: harness.main, in: harness)

    harness.model.showFind()

    #expect(harness.model.findBarSessionIDs == [pane])
    #expect(harness.engine.searched.isEmpty, "nothing typed, nothing searched")
  }

  @Test func typingSearchesThePaneAndClearingTheFieldEndsTheEnginesSearch() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)

    harness.model.setFindText("make", of: pane)
    harness.model.setFindText("", of: pane)

    #expect(harness.engine.searched.map(\.id) == [pane, pane])
    #expect(harness.engine.searched.map(\.command) == [.find("make"), .find("")])
    #expect(harness.model.findText(of: pane) == "")
  }

  /// The field commits its binding again on Return, and a find is paired
  /// with a step in the engine: sent twice, Return skipped every other match.
  @Test func theSameFindTextAgainIsNotSearchedAgain() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)

    harness.model.setFindText("make", of: pane)
    harness.model.setFindText("make", of: pane)
    harness.model.findNext()

    #expect(harness.engine.searched.map(\.command) == [.find("make"), .nearest])
  }

  /// The engine selects nothing on a new find text, and a step sent with it runs
  /// before it has matched, so the first step lands nearest the prompt instead.
  @Test func theFirstStepAfterANewFindTextLandsNearestThePromptWhicheverArrowAsked() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)

    harness.model.setFindText("make", of: pane)
    harness.model.findPrevious()
    harness.model.findPrevious()
    harness.model.findNext()
    harness.model.setFindText("grep", of: pane)
    harness.model.findNext()
    harness.model.findNext()

    #expect(
      harness.engine.searched.map(\.command) == [
        .find("make"), .nearest, .previous, .next,
        .find("grep"), .nearest, .next,
      ]
    )
  }

  @Test func reopeningABarStartsItsSearchAgainFromNearestThePrompt() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.model.findNext()
    harness.model.closeFind(in: pane)

    harness.model.showFind()
    harness.model.findNext()

    #expect(harness.engine.searched.suffix(2).map(\.command) == [.find("make"), .nearest])
  }

  /// Clicking into a bar's field moves the store's focus nowhere, so the menu
  /// items would act on another pane's bar while the user types in this one.
  @Test func theMenuActsOnTheBarWhoseFieldHasTheKeyboard() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    harness.model.showFind()
    harness.model.setFindText("grep", of: second)

    harness.model.noteFindField(focused: true, of: first)
    harness.model.findNext()
    #expect(harness.engine.searched.last?.id == first)
    #expect(harness.model.findIsOpenInView)

    harness.model.closeFind()
    #expect(
      harness.model.findBarSessionIDs == [second],
      "the field's own bar closed, not the focused pane's",
    )
    #expect(harness.engine.focused.last == first)

    harness.model.noteFindField(focused: false, of: first)
    harness.model.findNext()
    #expect(
      harness.engine.searched.last?.id == second,
      "with no field focused, the pane in view's bar",
    )
  }

  @Test func nextAndPreviousMoveOnlyOnceSomethingIsTyped() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)

    harness.model.findNext()
    harness.model.findPrevious()
    #expect(harness.engine.searched.isEmpty, "an empty find text has nothing to move between")

    harness.model.setFindText("make", of: pane)
    harness.model.findNext()
    harness.model.findPrevious()
    #expect(harness.engine.searched.map(\.command) == [.find("make"), .nearest, .previous])
  }

  @Test func closingEndsTheSearchAndHandsTheKeyboardBackToThePane() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    let focusedBefore = harness.engine.focused.count

    harness.model.closeFind(in: pane)

    #expect(harness.model.findBarSessionIDs.isEmpty)
    #expect(harness.engine.searched.last?.command == .end)
    #expect(harness.engine.focused.count == focusedBefore + 1)
    #expect(harness.model.findText(of: pane) == "make", "the find text waits for the next open")
  }

  @Test func closingFindInAPaneWithNoBarDoesNothing() {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = focusedPane(of: harness.main, in: harness)
    let focusedBefore = harness.engine.focused.count

    harness.model.closeFind(in: pane)

    #expect(harness.engine.searched.isEmpty)
    #expect(harness.engine.focused.count == focusedBefore)
  }

  @Test func openingAgainSearchesTheKeptFindTextSoItsMatchesLightUp() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.model.closeFind(in: pane)

    harness.model.showFind()

    #expect(harness.engine.searched.last?.command == .find("make"))
  }

  @Test func findNextWithTheBarClosedDoesNothingAndTheMenuItemSaysSo() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    #expect(harness.model.findIsOpenInView)
    harness.model.closeFind(in: pane)
    #expect(!harness.model.findIsOpenInView)

    harness.model.findNext()
    harness.model.findPrevious()

    #expect(harness.model.findBarSessionIDs.isEmpty)
    #expect(harness.engine.searched.last?.command == .end)
  }

  @Test func closeFindTakesDownThePaneInViewsBarAndNoOther() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    harness.model.showFind()
    let focusedBefore = harness.engine.focused.count

    harness.model.closeFind()

    #expect(harness.model.findBarSessionIDs == [first])
    #expect(harness.engine.searched.last?.id == second)
    #expect(harness.engine.searched.last?.command == .end)
    #expect(harness.engine.focused.count == focusedBefore + 1)

    harness.model.closeFind()
    #expect(
      harness.model.findBarSessionIDs == [first],
      "no bar on the pane in view, nothing to close",
    )
  }

  @Test func findAsksForTheFieldOnceAndAgainOnEveryCmdFAndSearchesNothingTwice() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    #expect(harness.model.takeFindFieldRequest(pane))
    #expect(!harness.model.takeFindFieldRequest(pane), "one Cmd+F, one claim")

    harness.model.showFind()

    #expect(harness.model.takeFindFieldRequest(pane))
    #expect(harness.engine.searched.map(\.command) == [.find("make")])
  }

  @Test func aBarShownAgainByAWorktreeSwitchLeavesTheKeyboardInThePane() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    _ = harness.model.takeFindFieldRequest(pane)

    harness.model.select(harness.feature)
    harness.model.select(harness.main)

    #expect(harness.model.findBarSessionIDs.contains(pane), "the bar is still up")
    #expect(!harness.model.takeFindFieldRequest(pane), "and nothing asked for its field")
  }

  @Test func escapeInABarHandsTheKeyboardToThatBarsPaneNotTheFocusedOne() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    #expect(harness.engine.focused.last == second)

    harness.model.closeFind(in: first)

    #expect(harness.engine.focused.last == first)
  }

  @Test func findOnASecondPaneOpensItsOwnBarAndLeavesTheFirstsSearchRunning() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    #expect(second != first)

    harness.model.showFind()
    harness.model.setFindText("grep", of: second)

    #expect(harness.model.findBarSessionIDs == [first, second])
    #expect(harness.model.findText(of: first) == "make")
    #expect(harness.model.findText(of: second) == "grep")
    #expect(harness.engine.searched.map(\.id) == [first, second])
    #expect(harness.engine.searched.map(\.command) == [.find("make"), .find("grep")])
  }

  @Test func aBarsOwnArrowsStepItsOwnPaneWhileAnotherPaneHasTheKeyboard() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)

    harness.model.findNext(in: first)
    harness.model.findPrevious(in: first)
    harness.model.findNext(in: second)

    #expect(harness.engine.searched.map(\.id) == [first, first, first])
    #expect(harness.engine.searched.map(\.command) == [.find("make"), .nearest, .previous])
    #expect(harness.model.findBarSessionIDs == [first], "the second pane has no bar and gets none")
  }

  @Test func findNextInAnotherWorktreeIsDisabledAndLeavesTheFirstPanesSearchAlone() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.select(harness.feature)
    let other = focusedPane(of: harness.feature, in: harness)

    #expect(!harness.model.findIsOpenInView)
    harness.model.findNext()
    #expect(harness.model.findBarSessionIDs == [first])
    #expect(
      harness.engine.searched.map(\.id) == [first],
      "the first pane's search was neither moved nor ended",
    )

    harness.model.showFind()
    #expect(harness.model.findBarSessionIDs == [first, other])
    #expect(
      harness.model.findText(of: other) == "",
      "a new bar starts empty, not with another pane's find text",
    )
  }

  @Test func closingThePaneTakesItsBarAndFindTextWithIt() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.engine.searched = []

    harness.model.closeActivePane()

    #expect(harness.model.findBarSessionIDs.isEmpty)
    #expect(harness.model.findText(of: pane) == "")
    #expect(harness.engine.searched.isEmpty, "a gone pane is told nothing")
  }

  @Test func aShellExitingUnderTheBarTakesItWithItAndCmdFThenOpensOnTheLivePane() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let gone = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: gone)

    harness.engine.delegate?.terminalHost(harness.engine, didExit: gone)

    #expect(harness.model.findBarSessionIDs.isEmpty)
    #expect(!harness.model.findIsOpenInView)
    harness.model.showFind()
    let live = focusedPane(of: harness.main, in: harness)
    #expect(live != gone)
    #expect(harness.model.findBarSessionIDs == [live])
  }

  @Test func findIsOfferedOnlyWhileATerminalTabIsInView() {
    let harness = Harness()
    #expect(!harness.model.findIsAvailable, "nothing selected at launch")

    harness.model.select(harness.main)
    #expect(harness.model.findIsAvailable)

    harness.model.showAgentBoard()
    #expect(!harness.model.findIsAvailable)
    harness.model.hideAgentBoard()

    harness.model.closeActiveTab()
    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(!harness.model.findIsAvailable, "a worktree with no tab has nothing to search")
  }

  /// A bar torn down may never report its field losing the keyboard, so the
  /// field's pane must not keep the menu on a bar that is gone.
  @Test func closingTheFieldsBarHandsTheMenuBackToTheFocusedPanesBar() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    harness.model.showFind()
    harness.model.setFindText("grep", of: second)
    harness.model.noteFindField(focused: true, of: first)

    harness.model.closeFind(in: first)

    #expect(harness.model.findFieldSessionID == nil)
    #expect(harness.model.findIsOpenInView, "the focused pane's bar is still up")
    harness.model.findNext()
    #expect(harness.engine.searched.last?.id == second)
  }

  /// A switch hands the keyboard to a pane without the field saying it lost
  /// it, and a stale field would keep the menu on the wrong pane's bar.
  @Test func handingTheKeyboardToAPaneForgetsWhichFieldHadIt() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.noteFindField(focused: true, of: first)

    harness.model.select(harness.feature)

    #expect(harness.model.findFieldSessionID == nil)
  }

  @Test func cmdFInAFieldAsksForThatFieldAgainRatherThanOpeningTheFocusedPanesBar() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    _ = harness.model.takeFindFieldRequest(first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    harness.model.noteFindField(focused: true, of: first)

    harness.model.showFind()

    #expect(harness.model.findBarSessionIDs == [first], "no bar opened on the focused pane")
    #expect(harness.model.takeFindFieldRequest(first))
    #expect(!harness.model.findBarSessionIDs.contains(second))
  }

  @Test func findDoesNothingUnderTheBoardOrFromAnotherWindow() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.showAgentBoard()
    harness.model.showFind()
    harness.model.findNext()
    #expect(harness.model.findBarSessionIDs.isEmpty)
    #expect(!harness.model.findIsOpenInView)

    harness.model.hideAgentBoard()
    harness.platform.workspaceWindowIsKey = false
    harness.model.showFind()
    harness.model.findNext()
    #expect(harness.model.findBarSessionIDs.isEmpty)
  }

  private func paneWithFindOpen(_ harness: Harness) -> TerminalSession.ID {
    if harness.model.workspace.selectedWorktreeID == nil { harness.model.select(harness.main) }
    harness.model.showFind()
    return focusedPane(of: harness.main, in: harness)
  }

  private func focusedPane(of worktree: Worktree, in harness: Harness) -> TerminalSession.ID {
    harness.model.workspace.activeTab(in: worktree.id)!.focusedSessionID
  }
}
