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

    #expect(harness.model.findBarTargetIDs == [pane])
    #expect(harness.engine.searched.isEmpty, "nothing typed, nothing searched")
  }

  @Test func typingSearchesThePaneAndClearingTheFieldEndsTheEnginesSearch() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)

    harness.model.setFindText("make", of: pane)
    harness.model.setFindText("", of: pane)

    #expect(harness.engine.searched.map(\.id) == [pane, pane])
    #expect(harness.engine.searched.map(\.step) == [.find("make"), .find("")])
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

    #expect(harness.engine.searched.map(\.step) == [.find("make"), .nearest])
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
      harness.engine.searched.map(\.step) == [
        .find("make"), .nearest, .previous, .next,
        .find("grep"), .nearest, .next,
      ]
    )
  }

  @Test func aFindTextDifferingOnlyInCaseKeepsTheSelectionSoTheNextStepMovesOn() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)

    harness.model.setFindText("make", of: pane)
    harness.model.findNext()
    harness.model.setFindText("MAKE", of: pane)
    harness.model.findNext()

    #expect(
      harness.engine.searched.map(\.step) == [.find("make"), .nearest, .find("MAKE"), .next]
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

    #expect(harness.engine.searched.suffix(2).map(\.step) == [.find("make"), .nearest])
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
      harness.model.findBarTargetIDs == [second],
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
    #expect(harness.engine.searched.map(\.step) == [.find("make"), .nearest, .previous])
  }

  @Test func closingEndsTheSearchAndHandsTheKeyboardBackToThePane() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    let focusedBefore = harness.engine.focused.count

    harness.model.closeFind(in: pane)

    #expect(harness.model.findBarTargetIDs.isEmpty)
    #expect(harness.engine.searched.last?.step == .end)
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

    #expect(harness.engine.searched.last?.step == .find("make"))
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

    #expect(harness.model.findBarTargetIDs.isEmpty)
    #expect(harness.engine.searched.last?.step == .end)
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

    #expect(harness.model.findBarTargetIDs == [first])
    #expect(harness.engine.searched.last?.id == second)
    #expect(harness.engine.searched.last?.step == .end)
    #expect(harness.engine.focused.count == focusedBefore + 1)

    harness.model.closeFind()
    #expect(
      harness.model.findBarTargetIDs == [first],
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
    #expect(harness.engine.searched.map(\.step) == [.find("make")])
  }

  @Test func aBarShownAgainByAWorktreeSwitchLeavesTheKeyboardInThePane() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    _ = harness.model.takeFindFieldRequest(pane)

    harness.model.select(harness.feature)
    harness.model.select(harness.main)

    #expect(harness.model.findBarTargetIDs.contains(pane), "the bar is still up")
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

    #expect(harness.model.findBarTargetIDs == [first, second])
    #expect(harness.model.findText(of: first) == "make")
    #expect(harness.model.findText(of: second) == "grep")
    #expect(harness.engine.searched.map(\.id) == [first, second])
    #expect(harness.engine.searched.map(\.step) == [.find("make"), .find("grep")])
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
    #expect(harness.engine.searched.map(\.step) == [.find("make"), .nearest, .previous])
    #expect(harness.model.findBarTargetIDs == [first], "the second pane has no bar and gets none")
  }

  @Test func findNextInAnotherWorktreeIsDisabledAndLeavesTheFirstPanesSearchAlone() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: first)
    harness.model.select(harness.feature)
    let other = focusedPane(of: harness.feature, in: harness)

    #expect(!harness.model.findIsOpenInView)
    harness.model.findNext()
    #expect(harness.model.findBarTargetIDs == [first])
    #expect(
      harness.engine.searched.map(\.id) == [first],
      "the first pane's search was neither moved nor ended",
    )

    harness.model.showFind()
    #expect(harness.model.findBarTargetIDs == [first, other])
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

    #expect(harness.model.findBarTargetIDs.isEmpty)
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

    #expect(harness.model.findBarTargetIDs.isEmpty)
    #expect(!harness.model.findIsOpenInView)
    harness.model.showFind()
    let live = focusedPane(of: harness.main, in: harness)
    #expect(live != gone)
    #expect(harness.model.findBarTargetIDs == [live])
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

    #expect(harness.model.findFieldTargetID == nil)
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

    #expect(harness.model.findFieldTargetID == nil)
  }

  @Test func cmdFInAFieldAsksForThatFieldAgainRatherThanOpeningTheFocusedPanesBar() {
    let harness = Harness()
    let first = paneWithFindOpen(harness)
    _ = harness.model.takeFindFieldRequest(first)
    harness.model.splitActivePane(.horizontal)
    let second = focusedPane(of: harness.main, in: harness)
    harness.model.noteFindField(focused: true, of: first)

    harness.model.showFind()

    #expect(harness.model.findBarTargetIDs == [first], "no bar opened on the focused pane")
    #expect(harness.model.takeFindFieldRequest(first))
    #expect(!harness.model.findBarTargetIDs.contains(second))
  }

  @Test func findDoesNothingUnderTheBoardOrFromAnotherWindow() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.showAgentBoard()
    harness.model.showFind()
    harness.model.findNext()
    #expect(harness.model.findBarTargetIDs.isEmpty)
    #expect(!harness.model.findIsOpenInView)

    harness.model.hideAgentBoard()
    harness.platform.isWorkspaceWindowKey = false
    harness.model.showFind()
    harness.model.findNext()
    #expect(harness.model.findBarTargetIDs.isEmpty)
  }

  @Test func aFindTextInAnotherCaseKeepsTheCountAndANewOneDropsIt() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("error", of: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(3), in: pane)

    harness.model.setFindText("ERROR", of: pane)
    #expect(harness.model.searchCounts[pane]?.total == 3)
    harness.model.setFindText("warning", of: pane)
    #expect(harness.model.searchCounts[pane]?.total == nil)
  }

  @Test func aStepDropsTheSelectionItLeavesUntilTheEngineSaysTheNewOne() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("x", of: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(5), in: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .selected(4), in: pane)

    harness.model.findNext(in: pane)

    #expect(harness.model.searchCounts[pane]?.selected == nil)
    #expect(harness.model.searchCounts[pane]?.total == 5)
  }

  @Test func aStepOverTheOnlyMatchKeepsTheSelectionTheEngineWillNotResend() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("x", of: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .total(1), in: pane)
    harness.model.findNext(in: pane)
    harness.engine.delegate?.terminalHost(harness.engine, didCount: .selected(0), in: pane)

    harness.model.findNext(in: pane)

    #expect(harness.model.searchCounts[pane]?.selected == 0)
  }

  @Test func cmdFOverASelectionInThePaneSearchesForItsText() {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = focusedPane(of: harness.main, in: harness)
    harness.engine.selectionTexts[pane] = "make test"

    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "make test")
    #expect(harness.engine.searched.map(\.step) == [.find("make test")])
    #expect(harness.model.takeFindFieldRequest(pane))
  }

  @Test func cmdFOverASelectionReplacesTheFindTextOfABarAlreadyUp() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    engineReports(.total(3), in: pane, harness)
    harness.engine.selectionTexts[pane] = "grep"

    harness.model.showFind()
    harness.model.findNext()

    #expect(harness.model.findText(of: pane) == "grep")
    #expect(harness.model.findMatchCount(of: pane) == nil, "a new find text drops the old count")
    #expect(harness.engine.searched.suffix(2).map(\.step) == [.find("grep"), .nearest])
  }

  @Test func reopeningOverASelectionOfTheKeptFindTextSearchesItAgain() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.model.closeFind(in: pane)
    harness.engine.selectionTexts[pane] = "make"

    harness.model.showFind()

    #expect(harness.engine.searched.last?.step == .find("make"))
  }

  @Test func cmdFInTheFieldKeepsWhatWasTypedThereOverThePanesSelection() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.model.noteFindField(focused: true, of: pane)
    harness.engine.selectionTexts[pane] = "grep"

    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "make")
    #expect(harness.engine.searched.map(\.step) == [.find("make")])
  }

  @Test func aSelectionAlreadyTakenLeavesWhatWasTypedAfterIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = focusedPane(of: harness.main, in: harness)
    harness.engine.selectionTexts[pane] = "error"
    harness.model.showFind()
    harness.model.setFindText("warning", of: pane)
    harness.model.closeFind(in: pane)

    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "warning")
    #expect(harness.engine.searched.last?.step == .find("warning"))
  }

  @Test func aSelectionMatchingTheFindTextIsTakenSoItCannotLaterReplaceWhatWasTyped() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.engine.selectionTexts[pane] = "make"
    harness.model.showFind()
    harness.model.setFindText("warning", of: pane)
    harness.model.closeFind(in: pane)

    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "warning")
  }

  @Test func aSelectionClearedBeforeACmdFCanBeTakenAgain() {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = focusedPane(of: harness.main, in: harness)
    harness.engine.selectionTexts[pane] = "error"
    harness.model.showFind()
    harness.model.setFindText("warning", of: pane)
    harness.model.closeFind(in: pane)
    harness.engine.selectionTexts[pane] = nil
    harness.model.showFind()
    harness.model.closeFind(in: pane)

    harness.engine.selectionTexts[pane] = "error"
    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "error")
  }

  @Test func aSelectionDraggedPastItsLastLetterIsFoundWithoutTheTrailingSpaces() {
    let harness = Harness()
    harness.model.select(harness.main)
    let pane = focusedPane(of: harness.main, in: harness)
    harness.engine.selectionTexts[pane] = "main   "

    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "main")
  }

  @Test(arguments: ["make\ntest", "   "])
  func aSelectionOverSeveralLinesOrOfOnlySpacesIsNotTaken(selection: String) {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.model.closeFind(in: pane)
    harness.engine.selectionTexts[pane] = selection

    harness.model.showFind()

    #expect(harness.model.findText(of: pane) == "make")
  }

  @Test func theCountNumbersMatchesDownTheScrollbackAsNextWalksTowardsThePrompt() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    #expect(harness.model.findMatchCount(of: pane) == nil)

    engineReports(.total(5), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == FindMatchCount(position: nil, total: 5))

    harness.model.findNext(in: pane)
    engineReports(.selected(0), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane)?.position == 5, "nearest the prompt is last")

    harness.model.findNext(in: pane)
    engineReports(.selected(4), in: pane, harness)
    #expect(
      harness.model.findMatchCount(of: pane)?.position == 1,
      "past the prompt wraps to the top",
    )

    harness.model.findNext(in: pane)
    engineReports(.selected(3), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane)?.position == 2)
  }

  @Test func aStepKeepsShowingTheMatchItLeftUntilTheEngineNamesTheNext() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("x", of: pane)
    engineReports(.total(5), in: pane, harness)
    harness.model.findNext(in: pane)
    engineReports(.selected(0), in: pane, harness)

    harness.model.findNext(in: pane)
    #expect(harness.model.findMatchCount(of: pane)?.position == 5)

    engineReports(.selected(4), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane)?.position == 1)
  }

  /// The engine posts a total of 0 for the search a new find text replaces,
  /// then counts afresh from nothing.
  @Test func theEngineEndingTheReplacedSearchIsNotCountedAsNoMatches() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    engineReports(.total(3), in: pane, harness)

    harness.model.setFindText("zzz", of: pane)
    engineReports(.total(0), in: pane, harness)
    engineReports(.selected(nil), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == nil)

    engineReports(.total(0), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == FindMatchCount(position: nil, total: 0))
  }

  /// A closed bar's search thread is gone, so a fresh one ends nothing.
  @Test func reopeningOverANewSelectionCountsItsFirstTotalEvenWhenNone() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    harness.model.closeFind(in: pane)
    harness.engine.selectionTexts[pane] = "zzz"

    harness.model.showFind()
    engineReports(.total(0), in: pane, harness)

    #expect(harness.model.findMatchCount(of: pane) == FindMatchCount(position: nil, total: 0))
  }

  /// Typing ahead of the engine queues the counts of each find text passed
  /// through, and a 0 ending each, before the counts of the last.
  @Test func countsForFindTextsTypedPastAreDroppedUntilTheLastSearchStarts() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("m", of: pane)
    harness.model.setFindText("ma", of: pane)
    harness.model.setFindText("mak", of: pane)

    engineReports(.total(5), in: pane, harness)
    engineReports(.total(0), in: pane, harness)
    engineReports(.total(2), in: pane, harness)
    engineReports(.total(0), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == nil)

    engineReports(.total(1), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == FindMatchCount(position: nil, total: 1))
  }

  /// An empty find text stops the engine's search thread, which posts no total
  /// as it quits; the next find text starts a thread of its own.
  @Test func emptyingTheFieldShowsNoCountAndTheNextFindTextCountsAfresh() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    engineReports(.total(3), in: pane, harness)

    harness.model.setFindText("", of: pane)
    engineReports(.total(nil), in: pane, harness)
    engineReports(.selected(nil), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == nil)

    harness.model.setFindText("grep", of: pane)
    engineReports(.total(5), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane) == FindMatchCount(position: nil, total: 5))
  }

  /// Switching to the alternate screen posts that screen's total, but no
  /// selected match where the engine's notice of it was already none.
  @Test func aSelectedMatchPastANewTotalIsShownAsNoneSelected() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("make", of: pane)
    engineReports(.total(34), in: pane, harness)
    harness.model.findNext(in: pane)
    engineReports(.selected(20), in: pane, harness)
    #expect(harness.model.findMatchCount(of: pane)?.position == 14)

    engineReports(.total(3), in: pane, harness)

    #expect(harness.model.findMatchCount(of: pane) == FindMatchCount(position: nil, total: 3))
  }

  @Test func aClosedBarCountsNothing() {
    let harness = Harness()
    let pane = paneWithFindOpen(harness)
    harness.model.setFindText("x", of: pane)
    engineReports(.total(5), in: pane, harness)

    harness.model.closeFind(in: pane)

    #expect(harness.model.findMatchCount(of: pane) == nil)
  }

  private func engineReports(
    _ count: TerminalSearchCount,
    in pane: TerminalSession.ID,
    _ harness: Harness,
  ) {
    harness.engine.delegate?.terminalHost(harness.engine, didCount: count, in: pane)
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
