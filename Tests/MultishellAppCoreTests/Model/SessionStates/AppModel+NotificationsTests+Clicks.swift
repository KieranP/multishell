import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelNotificationsTests {
  /// A network volume can unmount between the report and the click. `select` refuses,
  /// and what follows would otherwise rewrite the active tab of a worktree nobody can reach.
  @Test func aClickOnAWorktreeThatHasGoneActivatesNothing() throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    let first = try #require(harness.model.workspace.activeTab(in: harness.feature.id))
    harness.model.newTab()
    let second = try #require(harness.model.workspace.activeTab(in: harness.feature.id))
    #expect(second.id != first.id)
    harness.model.select(harness.main)
    let selected = harness.model.workspace.selectedWorktreeID

    try FileManager.default.removeItem(at: harness.feature.path)
    harness.model.revealNotificationSubject(.session(first.focusedSessionID))

    #expect(
      harness.model.presentedError?.title == PresentedError.worktreeDirectoryMissing("").title
    )
    #expect(harness.model.workspace.selectedWorktreeID == selected, "the selection stands")
    #expect(
      harness.model.workspace.activeTab(in: harness.feature.id)?.id == second.id,
      "and the refused worktree's own strip is left as it was",
    )
  }

  @Test func aClickOnAWorktreeThatIsStillThereBringsItsTabUp() throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.feature.id))
    harness.model.select(harness.main)

    harness.model.revealNotificationSubject(.session(tab.focusedSessionID))

    #expect(harness.model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(harness.model.workspace.activeTab(in: harness.feature.id)?.id == tab.id)
  }

  @Test func aClickInAnotherWorktreeLeavesTheDoneOfItsOtherActiveTabUnseen() throws {
    let harness = Harness()
    let clicked = harness.openBackgroundTab()
    let passedOver = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.select(harness.feature)
    harness.messageSource.send(
      SessionStateReport(state: .done, sessionID: passedOver.focusedSessionID)
    )

    harness.model.revealNotificationSubject(.session(clicked.focusedSessionID))

    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == clicked.id)
    #expect(harness.model.state(ofPane: passedOver.focusedSessionID) == .done)
  }

  @Test func aClickOnTheUnfocusedPaneOfASplitHandsThatPaneTheKeyboard() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    let clicked = try #require(tab.sessionIDs.first { $0 != tab.focusedSessionID })
    harness.model.select(harness.feature)

    harness.model.revealNotificationSubject(.session(clicked))

    #expect(harness.engine.focused.last == clicked)
  }

  @Test func aBannerClickReachesTheModelThroughTheNotifier() {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id != first.id)

    harness.notifier.onActivate?(.session(first.focusedSessionID))

    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == first.id)
  }
}
