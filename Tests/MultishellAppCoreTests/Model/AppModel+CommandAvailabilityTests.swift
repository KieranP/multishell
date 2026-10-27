import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelCommandAvailabilityTests {
  @Test func withNoWorktreeSelectedNoTabCommandCanAct() {
    let harness = Harness()

    #expect(!harness.model.canOpenTab)
    #expect(!harness.model.canSplitPane)
    #expect(!harness.model.canActivateAnotherTab)
    #expect(!harness.model.canMoveActiveTabToNewGroup)
    #expect(!harness.model.canFocusAnotherGroup)
    #expect(!harness.model.canOpenWorktreeInEditor)
  }

  @Test func overTheAgentsBoardNoTabCommandCanAct() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.toggleAgentBoard()

    #expect(!harness.model.canOpenTab)
    #expect(!harness.model.canSplitPane)
    #expect(!harness.model.canOpenWorktreeInEditor)
  }

  @Test func aWorktreeWithNoTabOpenCanOpenOneButNotSplit() {
    let harness = Harness()

    harness.model.select(harness.feature, openingFirstTab: .never)

    #expect(harness.model.canOpenTab)
    #expect(!harness.model.canSplitPane)
    #expect(harness.model.canOpenWorktreeInEditor)
  }

  @Test func oneTabCanSplitButHasNoOtherTabOrGroupToGoTo() {
    let harness = Harness()

    harness.model.select(harness.main)

    #expect(harness.model.canSplitPane)
    #expect(!harness.model.canActivateAnotherTab)
    #expect(!harness.model.canMoveActiveTabToNewGroup)
    #expect(!harness.model.canFocusAnotherGroup)
  }

  @Test func twoTabsStepAndMoveAndTwoGroupsFocusEachOther() {
    let harness = Harness()
    _ = harness.openBackgroundTab()
    #expect(harness.model.canActivateAnotherTab)
    #expect(harness.model.canMoveActiveTabToNewGroup)

    harness.model.moveActiveTabToNewGroup()

    #expect(harness.model.canFocusAnotherGroup)
  }

  @Test func aWorktreeACreateOrRemoveHoldsOpensNoTabAndNoEditor() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.worktreeOperations.begin(.removingWorktree, on: harness.main.id)

    #expect(!harness.model.canOpenTab)
    #expect(!harness.model.canOpenWorktreeInEditor)
  }

  @Test func theFilesPanelNeedsAWorktreeInViewToShowItsFiles() {
    let harness = Harness()
    #expect(!harness.model.canToggleFilesPanel)

    harness.model.select(harness.main)
    #expect(harness.model.canToggleFilesPanel)

    harness.model.toggleAgentBoard()
    #expect(!harness.model.canToggleFilesPanel)
  }

  @Test func aFilesPanelLeftOnUnderACoverCanStillBeTurnedOff() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsFilesPanel(true)

    harness.model.toggleAgentBoard()

    #expect(harness.model.canToggleFilesPanel)
  }

  @Test func closingNeedsATabInView() {
    let harness = Harness()
    #expect(!harness.model.hasTabToClose)

    harness.model.select(harness.main)
    #expect(harness.model.hasTabToClose)

    harness.model.toggleAgentBoard()
    #expect(!harness.model.hasTabToClose)
  }

  @Test func aNewWorktreeNeedsAProjectToMakeItIn() {
    let harness = Harness()
    #expect(harness.model.canStartNewWorktree)

    harness.model.removeProject(harness.project)

    #expect(!harness.model.canStartNewWorktree)
  }
}
