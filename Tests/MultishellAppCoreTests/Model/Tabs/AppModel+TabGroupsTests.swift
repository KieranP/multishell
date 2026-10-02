import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTabGroupsTests {
  /// Two groups of the selected worktree, the second holding the tab that
  /// was active.
  private func twoGroups(_ h: Harness) -> (first: TabGroup, second: TabGroup) {
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let groups = h.model.workspace.groups(in: h.main.id)
    return (groups[0], groups[1])
  }

  @Test func moveTabToNewGroupDividesTheWorktreeWithoutRestartingAShell() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    let live = h.engine.liveSessionIDs
    let moving = h.model.workspace.activeTab(in: h.main.id)!

    h.model.moveActiveTabToNewGroup()

    let groups = h.model.workspace.groups(in: h.main.id)
    #expect(groups.count == 2)
    #expect(h.model.workspace.tabs(inGroup: groups[1].id).map(\.id) == [moving.id])
    #expect(h.model.focusedGroup?.id == groups[1].id)
    #expect(h.engine.liveSessionIDs == live, "the shells kept running")
    #expect(h.engine.closed.isEmpty)
  }

  /// Both groups are on screen, so both their tabs are live; nothing is
  /// closed for being in the group that lost the focus.
  @Test func everyGroupsTabKeepsItsShell() {
    let h = Harness()
    _ = twoGroups(h)
    let shown = h.model.workspace.shownTabs(in: h.main.id)

    #expect(shown.count == 2)
    for id in shown.flatMap(\.sessionIDs) {
      #expect(h.model.liveSessionIDs.contains(id))
      #expect(h.model.isPaneInView(id), "a pane in the next group over is being looked at")
    }
  }

  @Test func focusingAGroupHandsItTheKeyboard() {
    let h = Harness()
    let groups = twoGroups(h)
    let firstsTab = h.model.workspace.shownTab(in: groups.first)!

    h.model.focusPreviousGroup()

    #expect(h.model.focusedGroup?.id == groups.first.id)
    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == firstsTab.id)
    #expect(
      h.engine.focused.last == firstsTab.focusedSessionID,
      "the pane of the group that took the focus")

    h.model.focusNextGroup()
    #expect(h.model.focusedGroup?.id == groups.second.id, "and it wraps")
  }

  @Test func focusGoesNowhereWithOneGroup() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let before = h.model.workspace

    h.model.focusNextGroup()
    h.model.focusPreviousGroup()

    #expect(h.model.workspace == before)
  }

  /// Cmd+T opens in the focused group; a strip's own New Tab button names
  /// its group, so a click in one never opens a tab in another.
  @Test func aNewTabOpensInTheGroupThatAskedForIt() {
    let h = Harness()
    let groups = twoGroups(h)
    let before = h.model.workspace.tabs(inGroup: groups.first.id).count

    h.model.newTab(in: groups.first.id)

    #expect(h.model.workspace.tabs(inGroup: groups.first.id).count == before + 1)
    #expect(h.model.workspace.tabs(inGroup: groups.second.id).count == 1, "the other group stands")
    #expect(h.model.focusedGroup?.id == groups.first.id, "opening a tab there is working in it")

    h.model.newTab()
    #expect(
      h.model.workspace.tabs(inGroup: groups.first.id).count == before + 2,
      "the keystroke names no group and opens in the focused one")
  }

  @Test func aGroupLastsAsLongAsItHasATab() {
    let h = Harness()
    let groups = twoGroups(h)
    h.model.newTab(in: groups.second.id)
    #expect(h.model.workspace.tabs(inGroup: groups.second.id).count == 2)

    h.model.closeActiveTab()
    #expect(h.model.workspace.groups(in: h.main.id).count == 2, "one tab left in it")

    h.model.closeActiveTab()
    #expect(h.model.workspace.groups(in: h.main.id).map(\.id) == [groups.first.id])
    #expect(h.model.focusedGroup?.id == groups.first.id)
  }

  @Test func splittingActsInsideTheFocusedGroup() {
    let h = Harness()
    let groups = twoGroups(h)
    h.model.focusGroup(groups.first.id)

    h.model.splitActivePane(.vertical)

    #expect(h.model.workspace.shownTab(in: groups.first)?.isSplit == true)
    #expect(h.model.workspace.shownTab(in: groups.second)?.isSplit == false)
  }

  @Test func aSplitNamingAGroupActsInItAndFocusesIt() {
    let h = Harness()
    let groups = twoGroups(h)
    h.model.focusGroup(groups.first.id)

    h.model.splitActivePane(.horizontal, in: groups.second.id)

    #expect(h.model.workspace.shownTab(in: groups.second)?.isSplit == true)
    #expect(h.model.workspace.shownTab(in: groups.first)?.isSplit == false)
    #expect(h.model.focusedGroup?.id == groups.second.id)
  }

  /// A Done in another group is in view, so no banner, but not focused, so
  /// it stays until that group is: `isFocused` clears, `isPaneInView` holds the banner.
  @Test func aFinishedCommandInAnotherGroupWaitsForItsFocus() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    let groups = twoGroups(h)
    let watched = h.model.workspace.shownTab(in: groups.first)!.focusedSessionID
    #expect(h.model.focusedGroup?.id == groups.second.id)

    h.stateSource.send(SessionStateReport(state: .done, sessionID: watched, cwd: nil, pid: nil))

    #expect(h.model.sessionStates[.session(watched)] == .done, "in view, not looked at")
    #expect(h.notifier.posted.isEmpty, "in view, so nothing to tell them")

    h.model.focusGroup(groups.first.id)
    #expect(h.model.sessionStates[.session(watched)] == nil, "focusing it is seeing it")
  }
}
