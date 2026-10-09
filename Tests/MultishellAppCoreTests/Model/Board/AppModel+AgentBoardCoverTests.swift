import Foundation
import MultishellCore
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite
@MainActor
struct AppModelAgentBoardCoverTests {
  @Test func openingACardTurnsToItsPaneAndLeavesTheBoard() {
    let harness = Harness()
    harness.model.select(harness.feature)
    let session = harness.store.workspace.sessions[0]
    let model = harness.model
    model.setShowsAllTerminals(true)
    model.select(harness.main)
    model.showAgentBoard()

    let card = model.agentBoard.column(.idle).cards.first { $0.id == session.id }
    #expect(card != nil)
    model.show(card!)

    #expect(!model.showsAgentBoard)
    #expect(model.workspace.selectedWorktreeID == harness.feature.id)
    #expect(model.workspace.activeTab(in: harness.feature.id)?.id == card?.tabID)
    #expect(harness.engine.focused.last == session.id)
  }

  @Test func selectingAWorktreeLeavesTheBoard() {
    let harness = Harness()
    harness.model.showAgentBoard()
    #expect(harness.model.showsAgentBoard)
    harness.model.select(harness.feature)
    #expect(!harness.model.showsAgentBoard)
  }

  /// Clicking a row git no longer lists selects nothing, so closing the board would leave the
  /// user looking at a worktree they did not pick.
  @Test func aRowTheStoreNoLongerHasLeavesTheBoardUp() {
    let harness = Harness()
    let stale = harness.feature
    harness.store.replaceWorktrees([harness.main], forProject: harness.project.id)
    harness.model.showAgentBoard()

    #expect(!harness.model.select(stale))
    #expect(harness.model.showsAgentBoard)
    #expect(harness.model.workspace.selectedWorktreeID != stale.id)
  }

  /// A quiet agent is watched only while the board is up, since a dropped file asks about the pid
  /// when it lands; so opening the board sweeps once, or its first frame would be stale.
  @Test func openingTheBoardSweepsAnAgentThatWentQuietAndQuit() {
    let (harness, session) = Harness.withOnePane()
    let model = harness.model
    let gone = deadPID()

    harness.stateSource.send(
      SessionStateReport(state: .running, sessionID: session.id, pid: gone, agentID: "claude")
    )
    harness.stateSource.send(
      SessionStateReport(state: .idle, sessionID: session.id, pid: gone, agentID: "claude")
    )
    #expect(model.reportedAgents[session.id] != nil)
    #expect(!model.watchedPIDs.contains(gone), "nothing is being said about it")

    model.showAgentBoard()
    #expect(model.reportedAgents[session.id] == nil)
    #expect(model.agentBoard.isEmpty)
  }

  /// Cmd+W with the board up would otherwise end a shell in a pane nobody
  /// can see, and Cmd+T open a tab that appears only once the board is left.
  @Test func aKeystrokeAboutTheTerminalsDoesNothingBehindTheBoard() {
    let (harness, _) = Harness.withOnePane()
    let model = harness.model
    let tabs = model.workspace.tabs.count
    #expect(tabs == 1)

    model.showAgentBoard()
    model.newTab()
    model.newShellTab()
    model.splitActivePane(.horizontal)
    model.closeActivePane()
    model.closeActiveTab()
    model.moveActiveTabToNewGroup()
    model.activateNextTab()
    #expect(model.workspace.tabs.count == tabs, "nothing opened and nothing closed")
    #expect(model.workspace.sessions.count == 1)
    #expect(model.focusedGroup == nil)

    model.hideAgentBoard()
    model.newTab()
    #expect(model.workspace.tabs.count == tabs + 1)
  }
}
