import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelNotificationsTests {
  /// A network volume can unmount between the report and the click. `select` refuses,
  /// and what follows would otherwise rewrite the active tab of a worktree nobody can reach.
  @Test func aClickOnAWorktreeThatHasGoneActivatesNothing() throws {
    let h = Harness()
    h.model.select(h.feature)
    let first = try #require(h.model.workspace.activeTab(in: h.feature.id))
    h.model.newTab()
    let second = try #require(h.model.workspace.activeTab(in: h.feature.id))
    #expect(second.id != first.id)
    h.model.select(h.main)
    let selected = h.model.workspace.selectedWorktreeID

    try FileManager.default.removeItem(at: h.feature.path)
    h.model.revealNotificationSubject(.session(first.focusedSessionID))

    #expect(h.model.presentedError?.title == PresentedError.worktreeDirectoryMissing("").title)
    #expect(h.model.workspace.selectedWorktreeID == selected, "the selection stands")
    #expect(
      h.model.workspace.activeTab(in: h.feature.id)?.id == second.id,
      "and the refused worktree's own strip is left as it was")
  }

  @Test func aClickOnAWorktreeThatIsStillThereBringsItsTabUp() throws {
    let h = Harness()
    h.model.select(h.feature)
    let tab = try #require(h.model.workspace.activeTab(in: h.feature.id))
    h.model.select(h.main)

    h.model.revealNotificationSubject(.session(tab.focusedSessionID))

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
  }
}
