import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTabGroupsTests {
  /// Two groups of the selected worktree, the second holding the tab that
  /// was active.
  private func twoGroups(_ harness: Harness) -> (first: TabGroup, second: TabGroup) {
    harness.model.select(harness.main)
    harness.model.newTab()
    harness.model.newTab()
    harness.model.moveActiveTabToNewGroup()
    let groups = harness.model.workspace.groups(in: harness.main.id)
    return (groups[0], groups[1])
  }

  @Test func moveTabToNewGroupDividesTheWorktreeWithoutRestartingAShell() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    harness.model.newTab()
    let live = harness.engine.liveSessionIDs
    let moving = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.model.moveActiveTabToNewGroup()

    let groups = harness.model.workspace.groups(in: harness.main.id)
    #expect(groups.count == 2)
    #expect(harness.model.workspace.tabs(inGroup: groups[1].id).map(\.id) == [moving.id])
    #expect(harness.model.focusedGroup?.id == groups[1].id)
    #expect(harness.engine.liveSessionIDs == live, "the shells kept running")
    #expect(harness.engine.closed.isEmpty)
  }

  /// Both groups are on screen, so both their tabs are live; nothing is
  /// closed for being in the group that lost the focus.
  @Test func everyGroupsTabKeepsItsShell() {
    let harness = Harness()
    _ = twoGroups(harness)
    let shown = harness.model.workspace.shownTabs(in: harness.main.id)

    #expect(shown.count == 2)
    for id in shown.flatMap(\.sessionIDs) {
      #expect(harness.model.liveSessionIDs.contains(id))
      #expect(harness.model.isPaneInView(id), "a pane in the next group over is being looked at")
    }
  }

  @Test func focusingAGroupHandsItTheKeyboard() {
    let harness = Harness()
    let groups = twoGroups(harness)
    let firstsTab = harness.model.workspace.shownTab(in: groups.first)!

    harness.model.focusPreviousGroup()

    #expect(harness.model.focusedGroup?.id == groups.first.id)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == firstsTab.id)
    #expect(
      harness.engine.focused.last == firstsTab.focusedSessionID,
      "the pane of the group that took the focus")

    harness.model.focusNextGroup()
    #expect(harness.model.focusedGroup?.id == groups.second.id, "and it wraps")
  }

  @Test func focusGoesNowhereWithOneGroup() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let before = harness.model.workspace

    harness.model.focusNextGroup()
    harness.model.focusPreviousGroup()

    #expect(harness.model.workspace == before)
  }

  /// Cmd+T opens in the focused group; a strip's own New Tab button names
  /// its group, so a click in one never opens a tab in another.
  @Test func aNewTabOpensInTheGroupThatAskedForIt() {
    let harness = Harness()
    let groups = twoGroups(harness)
    let before = harness.model.workspace.tabs(inGroup: groups.first.id).count

    harness.model.newTab(in: groups.first.id)

    #expect(harness.model.workspace.tabs(inGroup: groups.first.id).count == before + 1)
    #expect(
      harness.model.workspace.tabs(inGroup: groups.second.id).count == 1, "the other group stands")
    #expect(
      harness.model.focusedGroup?.id == groups.first.id, "opening a tab there is working in it")

    harness.model.newTab()
    #expect(
      harness.model.workspace.tabs(inGroup: groups.first.id).count == before + 2,
      "the keystroke names no group and opens in the focused one")
  }

  @Test func aGroupLastsAsLongAsItHasATab() {
    let harness = Harness()
    let groups = twoGroups(harness)
    harness.model.newTab(in: groups.second.id)
    #expect(harness.model.workspace.tabs(inGroup: groups.second.id).count == 2)

    harness.model.closeActiveTab()
    #expect(harness.model.workspace.groups(in: harness.main.id).count == 2, "one tab left in it")

    harness.model.closeActiveTab()
    #expect(harness.model.workspace.groups(in: harness.main.id).map(\.id) == [groups.first.id])
    #expect(harness.model.focusedGroup?.id == groups.first.id)
  }

  @Test func splittingActsInsideTheFocusedGroup() {
    let harness = Harness()
    let groups = twoGroups(harness)
    harness.model.focusGroup(groups.first.id)

    harness.model.splitActivePane(.vertical)

    #expect(harness.model.workspace.shownTab(in: groups.first)?.isSplit == true)
    #expect(harness.model.workspace.shownTab(in: groups.second)?.isSplit == false)
  }

  @Test func aSplitNamingAGroupActsInItAndFocusesIt() {
    let harness = Harness()
    let groups = twoGroups(harness)
    harness.model.focusGroup(groups.first.id)

    harness.model.splitActivePane(.horizontal, in: groups.second.id)

    #expect(harness.model.workspace.shownTab(in: groups.second)?.isSplit == true)
    #expect(harness.model.workspace.shownTab(in: groups.first)?.isSplit == false)
    #expect(harness.model.focusedGroup?.id == groups.second.id)
  }

  /// A Done in another group is in view, so no banner, but not focused, so
  /// it stays until that group is: `isFocused` clears, `isPaneInView` holds the banner.
  @Test func aFinishedCommandInAnotherGroupWaitsForItsFocus() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let groups = twoGroups(harness)
    let watched = harness.model.workspace.shownTab(in: groups.first)!.focusedSessionID
    #expect(harness.model.focusedGroup?.id == groups.second.id)

    harness.stateSource.send(
      SessionStateReport(state: .done, sessionID: watched, workingDirectory: nil, pid: nil))

    #expect(harness.model.sessionStates[.session(watched)] == .done, "in view, not looked at")
    #expect(harness.notifier.posted.isEmpty, "in view, so nothing to tell them")

    harness.model.focusGroup(groups.first.id)
    #expect(harness.model.sessionStates[.session(watched)] == nil, "focusing it is seeing it")
  }
}
