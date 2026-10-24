import Foundation

extension Workspace {
  /// Restores the invariants the store maintains between its collections
  /// after state comes off disk; see Docs/design/state-and-store.md.
  mutating func repair() {
    // A file can hold one identity twice where the store cannot, and a
    // repeat traps the first dictionary built from it. First entry wins.
    projects = projects.uniqued(by: \.id)
    sessions = sessions.uniqued(by: \.id)

    // Each dedup follows its own prune, never precedes it: first entry wins,
    // so a dead copy listed first is kept and the live one goes with it.
    let projectIDs = Set(projects.map(\.id))
    worktrees.removeAll { !projectIDs.contains($0.projectID) }
    worktrees = worktrees.uniqued(by: \.id)

    let worktreeIDs = Set(worktrees.map(\.id))
    tabs.removeAll { !worktreeIDs.contains($0.worktreeID) }
    tabs = tabs.uniqued(by: \.id)
    tabGroups.removeAll { !worktreeIDs.contains($0.worktreeID) }
    tabGroups = tabGroups.uniqued(by: \.id)

    repairPanes()
    pruneAndReassignSessions()
    repairFileTabs(worktreeIDs: worktreeIDs)

    // A name outliving its worktree returns if one is made at that path
    // again; a blank one draws an empty line over the branch.
    customWorktreeNames = customWorktreeNames.filter { id, name in
      worktreeIDs.contains(id) && name.trimmedOrNil != nil
    }

    repairGroups()
    repairPortBlocks()

    if let selected = selectedWorktreeID, !worktreeIDs.contains(selected) {
      selectedWorktreeID = nil
    }
  }

  /// Drops a block whose worktree is not listed or is bare, one no setting could
  /// fit, and a block already held, the worktree listed first keeping it.
  private mutating func repairPortBlocks() {
    var kept: [Worktree.ID: Int] = [:]
    var held: Set<Int> = []
    for worktree in worktrees where !worktree.isBare {
      guard let index = portBlocks[worktree.id], PortBlock.indices.contains(index),
        held.insert(index).inserted
      else { continue }
      kept[worktree.id] = index
    }
    portBlocks = kept
    settlePortBlocks()
  }

  /// One pass in display order drops missing and repeated sessions and
  /// collapses the splits that leaves: one shell, two views, otherwise.
  private mutating func repairPanes() {
    let sessionIDs = Set(sessions.map(\.id))
    var shown: Set<TerminalSession.ID> = []
    tabs = tabs.compactMap { tab in
      guard
        let root = tab.root.pruning({ id in
          !sessionIDs.contains(id) || !shown.insert(id).inserted
        })
      else { return nil }
      var repaired = tab
      repaired.root = root
      if !root.contains(repaired.focusedSessionID) {
        repaired.focusedSessionID = root.sessionIDs[0]
      }
      return repaired
    }
  }

  /// Drops a session no tab shows, and moves one listed under another
  /// worktree than its tab's to the tab's.
  private mutating func pruneAndReassignSessions() {
    var owner: [TerminalSession.ID: Worktree.ID] = [:]
    for tab in tabs {
      for id in tab.sessionIDs { owner[id] = tab.worktreeID }
    }
    sessions.removeAll { owner[$0.id] == nil }
    // Where the two disagree the tab's answer wins: it is what the sidebar
    // lists the tab under, and what decides whether its shell starts.
    let pathOfWorktree = worktrees.keyedByID().mapValues(\.path)
    for index in sessions.indices {
      guard let worktree = owner[sessions[index].id], worktree != sessions[index].worktreeID
      else { continue }
      sessions[index].worktreeID = worktree
      // The directory goes with it, as when a tab is moved, or the shell
      // starts in another worktree's checkout.
      if let path = pathOfWorktree[worktree] { sessions[index].workingDirectory = path }
    }
  }

  /// Drops a file tab whose worktree went, whose path leaves its worktree, or
  /// whose id another tab holds; one tab a path, the first kept.
  private mutating func repairFileTabs(worktreeIDs: Set<Worktree.ID>) {
    let terminalIDs = Set(tabs.map(\.id))
    fileTabs.removeAll { tab in
      !worktreeIDs.contains(tab.worktreeID) || !FileTab.isContained(tab.path)
        || terminalIDs.contains(tab.id)
    }
    fileTabs = fileTabs.uniqued(by: \.id)
    var seen: Set<[String]> = []
    fileTabs.removeAll { !seen.insert([$0.worktreeID, $0.path]).inserted }
  }

  /// Puts the groups right once the passes above have settled the tabs. A
  /// missing group loses the group, not the tab: one is a layout.
  private mutating func repairGroups() {
    adoptUngroupedTabs()

    // An empty group draws a strip with no tabs over a pane with no
    // terminal, and nothing else here would take it away.
    let occupied = Set(tabs.map(\.groupID) + fileTabs.map(\.groupID))
    tabGroups.removeAll { !occupied.contains($0.id) }

    for index in tabGroups.indices {
      // A width of zero is a group nothing can be laid out in. Decoding
      // makes the same substitution; a half-written save can leave one.
      tabGroups[index].weight = LayoutWeight.usable(tabGroups[index].weight)
      let groupID = tabGroups[index].id
      // An older build's file has no order, so its tabs keep the array's.
      let live =
        tabs.filter { $0.groupID == groupID }.map(\.id)
        + fileTabs.filter { $0.groupID == groupID }.map(\.id)
      let kept = tabGroups[index].tabOrder.filter(Set(live).contains).uniqued(by: \.self)
      tabGroups[index].tabOrder = kept + live.filter { !kept.contains($0) }
      if let shown = tabGroups[index].shownTabID, live.contains(shown) { continue }
      // Any of them will do, nothing on disk saying which the group showed:
      // unlike `settle`, there is no vacated place to hand on.
      tabGroups[index].shownTabID = tabGroups[index].tabOrder.last
    }
    alignTabsToGroupOrder()

    // An entry with no groups left, or naming another worktree's, hides
    // the strip of the worktree it names.
    focusedGroupByWorktree = focusedGroupByWorktree.filter { worktreeID, groupID in
      group(groupID)?.worktreeID == worktreeID
    }
    for worktree in Set(tabGroups.map(\.worktreeID)) where focusedGroupByWorktree[worktree] == nil {
      focusedGroupByWorktree[worktree] = groups(in: worktree).first?.id
    }
  }

  /// Gives every tab that names no group one to sit in: a file from before
  /// tab groups, or one whose group was dropped. The first group takes them.
  mutating func adoptUngroupedTabs(shownTabByWorktree: [Worktree.ID: TerminalTab.ID] = [:]) {
    let known = tabGroups.keyedByID().mapValues(\.worktreeID)
    var minted: [Worktree.ID: TabGroup.ID] = [:]

    func home(forTab id: WorkspaceTab.ID, in worktreeID: Worktree.ID) -> TabGroup.ID {
      if let existing = minted[worktreeID] ?? groups(in: worktreeID).first?.id { return existing }
      let group = TabGroup(
        worktreeID: worktreeID,
        shownTabID: shownTabByWorktree[worktreeID] ?? id,
      )
      tabGroups.append(group)
      minted[worktreeID] = group.id
      if focusedGroupByWorktree[worktreeID] == nil { focusedGroupByWorktree[worktreeID] = group.id }
      return group.id
    }

    for index in tabs.indices where known[tabs[index].groupID] != tabs[index].worktreeID {
      tabs[index].groupID = home(forTab: tabs[index].id, in: tabs[index].worktreeID)
    }
    for index in fileTabs.indices where known[fileTabs[index].groupID] != fileTabs[index].worktreeID
    {
      fileTabs[index].groupID = home(forTab: fileTabs[index].id, in: fileTabs[index].worktreeID)
    }
  }
}
