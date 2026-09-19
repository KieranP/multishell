import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Every pane's find is its own and the search the engine's, so what is tested
/// is which panes have a bar and what each pane's engine was told.
@Suite @MainActor
struct AppModelFindTests {
  @Test func findOpensOnTheFocusedPaneOfTheShownTabWithoutSearchingYet() {
    let h = Harness()
    h.model.select(h.main)
    let pane = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID

    h.model.showFind()

    #expect(h.model.findingSessionIDs == [pane])
    #expect(h.engine.searched.isEmpty, "nothing typed, nothing searched")
  }

  @Test func typingSearchesThePaneAndClearingTheFieldEndsTheEnginesSearch() {
    let h = Harness()
    let pane = h.paneWithFindOpen()

    h.model.setFindText("make", of: pane)
    h.model.setFindText("", of: pane)

    #expect(h.engine.searched.map(\.id) == [pane, pane])
    #expect(h.engine.searched.map(\.command) == [.find("make"), .find("")])
    #expect(h.model.findText(of: pane) == "")
  }

  /// The field commits its binding again on Return, and a find is paired
  /// with a step in the engine: sent twice, Return skipped every other match.
  @Test func theSameNeedleAgainIsNotSearchedAgain() {
    let h = Harness()
    let pane = h.paneWithFindOpen()

    h.model.setFindText("make", of: pane)
    h.model.setFindText("make", of: pane)
    h.model.findNext()

    #expect(h.engine.searched.map(\.command) == [.find("make"), .nearest])
  }

  /// The engine selects nothing on a needle, and a step sent with it runs
  /// before it has matched, so the first step lands nearest the prompt instead.
  @Test func theFirstStepAfterANeedleLandsNearestThePromptWhicheverArrowAsked() {
    let h = Harness()
    let pane = h.paneWithFindOpen()

    h.model.setFindText("make", of: pane)
    h.model.findPrevious()
    h.model.findPrevious()
    h.model.findNext()
    h.model.setFindText("grep", of: pane)
    h.model.findNext()
    h.model.findNext()

    #expect(
      h.engine.searched.map(\.command) == [
        .find("make"), .nearest, .previous, .next,
        .find("grep"), .nearest, .next,
      ])
  }

  @Test func reopeningABarStartsItsSearchAgainFromNearestThePrompt() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    h.model.setFindText("make", of: pane)
    h.model.findNext()
    h.model.hideFind(of: pane)

    h.model.showFind()
    h.model.findNext()

    #expect(h.engine.searched.suffix(2).map(\.command) == [.find("make"), .nearest])
  }

  /// Clicking into a bar's field moves the store's focus nowhere, so the menu
  /// items would act on another pane's bar while the user types in this one.
  @Test func theMenuActsOnTheBarWhoseFieldHasTheKeyboard() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.setFindText("make", of: first)
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    h.model.showFind()
    h.model.setFindText("grep", of: second)

    h.model.noteFindField(focused: true, of: first)
    h.model.findNext()
    #expect(h.engine.searched.last?.id == first)
    #expect(h.model.findIsOpenInView)

    h.model.closeFind()
    #expect(
      h.model.findingSessionIDs == [second], "the field's own bar closed, not the focused pane's")
    #expect(h.engine.focused.last == first)

    h.model.noteFindField(focused: false, of: first)
    h.model.findNext()
    #expect(h.engine.searched.last?.id == second, "with no field focused, the pane in view's bar")
  }

  @Test func nextAndPreviousMoveOnlyOnceSomethingIsTyped() {
    let h = Harness()
    let pane = h.paneWithFindOpen()

    h.model.findNext()
    h.model.findPrevious()
    #expect(h.engine.searched.isEmpty, "an empty needle has nothing to move between")

    h.model.setFindText("make", of: pane)
    h.model.findNext()
    h.model.findPrevious()
    #expect(h.engine.searched.map(\.command) == [.find("make"), .nearest, .previous])
  }

  @Test func hidingEndsTheSearchAndHandsTheKeyboardBackToThePane() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    h.model.setFindText("make", of: pane)
    let focusedBefore = h.engine.focused.count

    h.model.hideFind(of: pane)

    #expect(h.model.findingSessionIDs.isEmpty)
    #expect(h.engine.searched.last?.command == .end)
    #expect(h.engine.focused.count == focusedBefore + 1)
    #expect(h.model.findText(of: pane) == "make", "the needle waits for the next open")
  }

  @Test func hidingAPaneWithNoBarDoesNothing() {
    let h = Harness()
    h.model.select(h.main)
    let pane = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    let focusedBefore = h.engine.focused.count

    h.model.hideFind(of: pane)

    #expect(h.engine.searched.isEmpty)
    #expect(h.engine.focused.count == focusedBefore)
  }

  @Test func openingAgainSearchesTheKeptNeedleSoItsMatchesLightUp() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    h.model.setFindText("make", of: pane)
    h.model.hideFind(of: pane)

    h.model.showFind()

    #expect(h.engine.searched.last?.command == .find("make"))
  }

  @Test func findNextWithTheBarClosedDoesNothingAndTheMenuItemSaysSo() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    h.model.setFindText("make", of: pane)
    #expect(h.model.findIsOpenInView)
    h.model.hideFind(of: pane)
    #expect(!h.model.findIsOpenInView)

    h.model.findNext()
    h.model.findPrevious()

    #expect(h.model.findingSessionIDs.isEmpty)
    #expect(h.engine.searched.last?.command == .end)
  }

  @Test func closeFindTakesDownThePaneInViewsBarAndNoOther() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.setFindText("make", of: first)
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    h.model.showFind()
    let focusedBefore = h.engine.focused.count

    h.model.closeFind()

    #expect(h.model.findingSessionIDs == [first])
    #expect(h.engine.searched.last?.id == second)
    #expect(h.engine.searched.last?.command == .end)
    #expect(h.engine.focused.count == focusedBefore + 1)

    h.model.closeFind()
    #expect(h.model.findingSessionIDs == [first], "no bar on the pane in view, nothing to close")
  }

  @Test func findAsksForTheFieldOnceAndAgainOnEveryCmdFAndSearchesNothingTwice() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    h.model.setFindText("make", of: pane)
    #expect(h.model.takeFindFieldRequest(pane))
    #expect(!h.model.takeFindFieldRequest(pane), "one Cmd+F, one claim")

    h.model.showFind()

    #expect(h.model.takeFindFieldRequest(pane))
    #expect(h.engine.searched.map(\.command) == [.find("make")])
  }

  @Test func aBarShownAgainByAWorktreeSwitchLeavesTheKeyboardInThePane() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    _ = h.model.takeFindFieldRequest(pane)

    h.model.select(h.feature)
    h.model.select(h.main)

    #expect(h.model.findingSessionIDs.contains(pane), "the bar is still up")
    #expect(!h.model.takeFindFieldRequest(pane), "and nothing asked for its field")
  }

  @Test func escapeInABarHandsTheKeyboardToThatBarsPaneNotTheFocusedOne() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    #expect(h.engine.focused.last == second)

    h.model.hideFind(of: first)

    #expect(h.engine.focused.last == first)
  }

  @Test func findOnASecondPaneOpensItsOwnBarAndLeavesTheFirstsSearchRunning() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.setFindText("make", of: first)
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    #expect(second != first)

    h.model.showFind()
    h.model.setFindText("grep", of: second)

    #expect(h.model.findingSessionIDs == [first, second])
    #expect(h.model.findText(of: first) == "make")
    #expect(h.model.findText(of: second) == "grep")
    #expect(h.engine.searched.map(\.id) == [first, second])
    #expect(h.engine.searched.map(\.command) == [.find("make"), .find("grep")])
  }

  @Test func aBarsOwnArrowsStepItsOwnPaneWhileAnotherPaneHasTheKeyboard() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.setFindText("make", of: first)
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID

    h.model.findNext(in: first)
    h.model.findPrevious(in: first)
    h.model.findNext(in: second)

    #expect(h.engine.searched.map(\.id) == [first, first, first])
    #expect(h.engine.searched.map(\.command) == [.find("make"), .nearest, .previous])
    #expect(h.model.findingSessionIDs == [first], "the second pane has no bar and gets none")
  }

  @Test func findNextInAnotherWorktreeIsDisabledAndLeavesTheFirstPanesSearchAlone() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.setFindText("make", of: first)
    h.model.select(h.feature)
    let other = h.model.workspace.activeTab(in: h.feature.id)!.focusedSessionID

    #expect(!h.model.findIsOpenInView)
    h.model.findNext()
    #expect(h.model.findingSessionIDs == [first])
    #expect(
      h.engine.searched.map(\.id) == [first], "the first pane's search was neither moved nor ended")

    h.model.showFind()
    #expect(h.model.findingSessionIDs == [first, other])
    #expect(
      h.model.findText(of: other) == "", "a new bar starts empty, not with another pane's needle")
  }

  @Test func closingThePaneTakesItsBarAndNeedleWithIt() {
    let h = Harness()
    let pane = h.paneWithFindOpen()
    h.model.setFindText("make", of: pane)
    h.engine.searched = []

    h.model.closeActivePane()

    #expect(h.model.findingSessionIDs.isEmpty)
    #expect(h.model.findText(of: pane) == "")
    #expect(h.engine.searched.isEmpty, "a gone pane is told nothing")
  }

  @Test func aShellExitingUnderTheBarTakesItWithItAndCmdFThenOpensOnTheLivePane() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let gone = h.paneWithFindOpen()
    h.model.setFindText("make", of: gone)

    h.engine.delegate?.terminalHost(h.engine, didExit: gone)

    #expect(h.model.findingSessionIDs.isEmpty)
    #expect(!h.model.findIsOpenInView)
    h.model.showFind()
    let live = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    #expect(live != gone)
    #expect(h.model.findingSessionIDs == [live])
  }

  @Test func findIsOfferedOnlyWhileATerminalTabIsInView() {
    let h = Harness()
    #expect(!h.model.findIsAvailable, "nothing selected at launch")

    h.model.select(h.main)
    #expect(h.model.findIsAvailable)

    h.model.showAgentBoard()
    #expect(!h.model.findIsAvailable)
    h.model.hideAgentBoard()

    h.model.closeActiveTab()
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(!h.model.findIsAvailable, "a worktree with no tab has nothing to search")
  }

  /// A bar torn down may never report its field losing the keyboard, so the
  /// field's pane must not keep the menu on a bar that is gone.
  @Test func closingTheFieldsBarHandsTheMenuBackToTheFocusedPanesBar() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.setFindText("make", of: first)
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    h.model.showFind()
    h.model.setFindText("grep", of: second)
    h.model.noteFindField(focused: true, of: first)

    h.model.hideFind(of: first)

    #expect(h.model.findFieldPane == nil)
    #expect(h.model.findIsOpenInView, "the focused pane's bar is still up")
    h.model.findNext()
    #expect(h.engine.searched.last?.id == second)
  }

  /// A switch hands the keyboard to a pane without the field saying it lost
  /// it, and a stale field would keep the menu on the wrong pane's bar.
  @Test func handingTheKeyboardToAPaneForgetsWhichFieldHadIt() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    h.model.noteFindField(focused: true, of: first)

    h.model.select(h.feature)

    #expect(h.model.findFieldPane == nil)
  }

  @Test func cmdFInAFieldAsksForThatFieldAgainRatherThanOpeningTheFocusedPanesBar() {
    let h = Harness()
    let first = h.paneWithFindOpen()
    _ = h.model.takeFindFieldRequest(first)
    h.model.splitActivePane(.horizontal)
    let second = h.model.workspace.activeTab(in: h.main.id)!.focusedSessionID
    h.model.noteFindField(focused: true, of: first)

    h.model.showFind()

    #expect(h.model.findingSessionIDs == [first], "no bar opened on the focused pane")
    #expect(h.model.takeFindFieldRequest(first))
    #expect(!h.model.findingSessionIDs.contains(second))
  }

  @Test func findDoesNothingUnderTheBoardOrFromAnotherWindow() {
    let h = Harness()
    h.model.select(h.main)

    h.model.showAgentBoard()
    h.model.showFind()
    h.model.findNext()
    #expect(h.model.findingSessionIDs.isEmpty)
    #expect(!h.model.findIsOpenInView)

    h.model.hideAgentBoard()
    h.platform.workspaceWindowIsKey = false
    h.model.showFind()
    h.model.findNext()
    #expect(h.model.findingSessionIDs.isEmpty)
  }
}

extension Harness {
  /// The main worktree selected and its focused pane's bar up.
  func paneWithFindOpen() -> TerminalSession.ID {
    if model.workspace.selectedWorktreeID == nil { model.select(main) }
    model.showFind()
    return model.workspace.activeTab(in: main.id)!.focusedSessionID
  }
}
