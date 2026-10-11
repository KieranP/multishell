import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellProcess

@Suite @MainActor
struct AppModelControlTabsTests {
  func order(
    _ worktree: String,
    agentID: String? = nil,
    task: String? = nil,
    command: [String]? = nil,
  )
    -> NewTabOrder
  {
    NewTabOrder(worktreeID: worktree, agentID: agentID, task: task, command: command)
  }

  @Test func theListingNamesEachWorktreesTabsAndPanesByTheIdsTheOtherRequestsTake() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))

    let reply = try #require(await harness.messageSource.ask(.listTabs(worktree: nil)))

    #expect(reply.outputFields["worktreeInView"] as? String == ControlID.worktree(harness.main.id))
    let worktrees = try #require(reply.outputFields["worktrees"] as? [[String: Any]])
    #expect(
      worktrees.compactMap { $0["id"] as? String } == [
        ControlID.worktree(harness.main.id), ControlID.worktree(harness.feature.id),
      ]
    )
    let tabs = try #require(worktrees[0]["tabs"] as? [[String: Any]])
    #expect(tabs.count == 1)
    #expect(tabs[0]["id"] as? String == tab.id.uuidString)
    #expect(tabs[0]["isShown"] as? Bool == true)
    let panes = try #require(tabs[0]["panes"] as? [[String: Any]])
    #expect(panes.compactMap { $0["id"] as? String } == tab.sessionIDs.map(\.uuidString))
    #expect(panes.allSatisfy { $0["isLive"] as? Bool == true })
    #expect(worktrees[1]["tabs"] is [Any])
  }

  @Test func theListingOfOneWorktreeHoldsItAloneWithEachPanesState() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .attention, sessionID: tab.focusedSessionID)
    )

    let reply = try #require(
      await harness.messageSource.ask(.listTabs(worktree: ControlID.worktree(harness.main.id)))
    )

    let worktrees = try #require(reply.outputFields["worktrees"] as? [[String: Any]])
    #expect(worktrees.count == 1)
    let tabs = try #require(worktrees[0]["tabs"] as? [[String: Any]])
    let panes = try #require(tabs[0]["panes"] as? [[String: Any]])
    #expect(panes[0]["state"] as? String == "attention")
    #expect(tabs[0]["state"] as? String == "attention")
  }

  @Test func aTabMovesBesideAnotherOfItsWorktreeAndNotBesideAnotherWorktrees() async throws {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    let second = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.select(harness.feature)
    let elsewhere = try #require(harness.model.workspace.activeTab(in: harness.feature.id))

    #expect(
      await harness.messageSource.ask(.moveTab(id: second.id, before: true, anchor: first.id))
        == .done
    )
    #expect(harness.model.workspace.tabs(in: harness.main.id).map(\.id) == [second.id, first.id])
    #expect(
      await harness.messageSource.ask(.moveTab(id: second.id, before: true, anchor: elsewhere.id))
        == .refused(.tabInAnotherWorktree(id: elsewhere.id))
    )
  }

  @Test func aRenameNamesTheTabAndNoTitleHandsItBackToTheShell() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))

    #expect(await harness.messageSource.ask(.renameTab(id: tab.id, title: "Server")) == .done)
    #expect(harness.model.workspace.tab(tab.id)?.customTitle == "Server")
    #expect(await harness.messageSource.ask(.renameTab(id: tab.id, title: nil)) == .done)
    #expect(harness.model.workspace.tab(tab.id)?.customTitle == nil)
  }

  @Test func selectingATabInAnotherWorktreeSelectsThatWorktreeAndShowsTheTab() async throws {
    let harness = Harness()
    harness.model.select(harness.feature)
    let background = harness.openBackgroundTab()

    let reply = await harness.messageSource.ask(.selectTab(id: background.id))

    #expect(reply == .done)
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == background.id)
  }

  @Test func anUnknownTabOrPaneIsRefusedByItsID() async {
    let harness = Harness()
    let id = UUID()

    #expect(await harness.messageSource.ask(.selectTab(id: id)) == .refused(.noTab(id: id)))
    #expect(
      await harness.messageSource.ask(.closeTab(id: id, force: true)) == .refused(.noTab(id: id))
    )
    #expect(await harness.messageSource.ask(.selectPane(id: id)) == .refused(.noPane(id: id)))
    #expect(
      await harness.messageSource.ask(.closePane(id: id, force: false)) == .refused(.noPane(id: id))
    )
  }

  @Test func closingOverAWorkingAgentIsRefusedWithNoDialogUnlessForced() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: tab.focusedSessionID)
    )

    #expect(
      await harness.messageSource.ask(.closeTab(id: tab.id, force: false))
        == .refused(.agentWorking)
    )
    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.tab(tab.id) != nil)

    #expect(
      await harness.messageSource.ask(.closePane(id: tab.focusedSessionID, force: true)) == .done
    )
    #expect(harness.model.workspace.tab(tab.id) == nil)
    #expect(harness.engine.closed == [tab.focusedSessionID])
  }

  @Test func renamingATabLeavesTheFieldOpenOnAnotherAlone() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let tabs = harness.model.workspace.tabs(in: harness.main.id)
    try #require(tabs.count == 2)
    harness.model.beginRenamingTab(tabs[0].id)

    let reply = await harness.messageSource.ask(.renameTab(id: tabs[1].id, title: "server"))

    #expect(reply == .done)
    #expect(harness.model.renamingTabID == tabs[0].id)
  }

  @Test func closingOrMovingTabsOutOfViewLeavesTheKeyboardWhereItIs() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let feature = ControlID.worktree(harness.feature.id)
    _ = await harness.messageSource.ask(.newTab(order(feature)))
    _ = await harness.messageSource.ask(.newTab(order(feature)))
    _ = await harness.messageSource.ask(.newTab(order(feature)))
    let tabs = harness.model.workspace.tabs(in: harness.feature.id)
    let field = try #require(
      harness.model.workspace.activeTab(in: harness.main.id)?.focusedSessionID
    )
    harness.model.noteFindField(focused: true, of: field)
    let focusedBefore = harness.engine.focused

    #expect(
      await harness.messageSource.ask(.moveTab(id: tabs[0].id, before: false, anchor: tabs[1].id))
        == .done
    )
    #expect(await harness.messageSource.ask(.closeTab(id: tabs[2].id, force: false)) == .done)
    #expect(
      await harness.messageSource.ask(.closePane(id: tabs[1].focusedSessionID, force: false))
        == .done
    )

    #expect(harness.model.findFieldSessionID == field)
    #expect(harness.engine.focused == focusedBefore)
  }
}
