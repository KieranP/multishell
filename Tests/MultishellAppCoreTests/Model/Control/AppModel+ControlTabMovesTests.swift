import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelControlTabMovesTests {
  @Test func aTabMovesBesideAnotherOfItsWorktreeAndNotBesideAnotherWorktrees() async throws {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    let second = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.select(harness.feature)
    let elsewhere = try #require(harness.model.workspace.activeTab(in: harness.feature.id))

    #expect(
      await harness.messageSource.ask(
        .moveTab(id: second.id, placement: .before, anchor: first.id)
      )
        == .done
    )
    #expect(harness.model.workspace.tabs(in: harness.main.id).map(\.id) == [second.id, first.id])
    #expect(
      await harness.messageSource.ask(
        .moveTab(id: second.id, placement: .before, anchor: elsewhere.id)
      )
        == .refused(.tabInAnotherWorktree(id: elsewhere.id))
    )
  }

  @Test func aTerminalTabMovesToAnotherWorktreeWithItsShellAndShowsIt() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))

    let reply = await harness.messageSource.ask(
      .moveTabToWorktree(id: tab.id, worktree: ControlID.worktree(harness.feature.id))
    )

    #expect(reply == .done)
    #expect(harness.model.workspace.tab(tab.id)?.worktreeID == harness.feature.id)
    #expect(harness.model.worktreeInView?.id == harness.feature.id)
    #expect(harness.engine.closed.isEmpty, "its shell goes with it")
  }

  @Test func aTabAlreadyInTheWorktreeOrAFileTabIsRefused() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    let file = harness.openFileTab()
    let main = ControlID.worktree(harness.main.id)
    let feature = ControlID.worktree(harness.feature.id)

    let same = await harness.messageSource.ask(.moveTabToWorktree(id: tab.id, worktree: main))
    let ofAFile = await harness.messageSource.ask(
      .moveTabToWorktree(id: file.id, worktree: feature)
    )

    #expect(same == .refused(.tabAlreadyThere(id: tab.id)))
    #expect(ofAFile == .refused(.tabShowsAFile(id: file.id)))
  }

  @Test func aTabGetsAGroupOfItsOwnButNotAGroupsOnlyTab() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))

    let alone = await harness.messageSource.ask(.moveTabToNewGroup(id: tab.id))
    let file = harness.openFileTab()
    let moved = await harness.messageSource.ask(.moveTabToNewGroup(id: file.id))

    #expect(alone == .refused(.onlyTabInGroup(id: tab.id)))
    #expect(moved == .done)
    #expect(harness.model.workspace.groups(in: harness.main.id).count == 2)
  }

  @Test func aNewGroupForATabOutOfViewLeavesTheKeyboardWhereItIs() async throws {
    let harness = Harness()
    let moved = harness.openBackgroundTab()
    harness.model.select(harness.feature)
    harness.engine.focused = []

    let reply = await harness.messageSource.ask(.moveTabToNewGroup(id: moved.id))

    #expect(reply == .done)
    #expect(harness.model.workspace.groups(in: harness.main.id).count == 2)
    #expect(harness.engine.focused.isEmpty)
  }
}
