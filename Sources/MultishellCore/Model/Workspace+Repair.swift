import Foundation

extension Workspace {
  /// Restores the invariants the store maintains between its collections
  /// after state comes off disk; see docs/design/state-and-store.md.
  public mutating func repairReferences() {
    // A file can hold one identity twice where the store cannot, and a
    // repeat traps the first dictionary built from it. First entry wins.
    projects = projects.uniqued(by: \.id)
    worktrees = worktrees.uniqued(by: \.id)
    sessions = sessions.uniqued(by: \.id)
    tabGroups = tabGroups.uniqued(by: \.id)
    // Tabs too: the pane pass below misses two tabs that share an id while
    // naming different sessions, and a strip would draw one id twice.
    tabs = tabs.uniqued(by: \.id)

    let projectIDs = Set(projects.map(\.id))
    worktrees.removeAll { !projectIDs.contains($0.projectID) }
    let worktreeIDs = Set(worktrees.map(\.id))
    tabs.removeAll { !worktreeIDs.contains($0.worktreeID) }
    tabGroups.removeAll { !worktreeIDs.contains($0.worktreeID) }

    // One pass in display order drops missing and repeated sessions and
    // collapses the splits that leaves: one shell, two views, otherwise.
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

    var owner: [TerminalSession.ID: Worktree.ID] = [:]
    for tab in tabs {
      for id in tab.sessionIDs { owner[id] = tab.worktreeID }
    }
    sessions.removeAll { owner[$0.id] == nil }
    // Where the two disagree the tab's answer wins: it is what the sidebar
    // lists the tab under, and what decides whether its shell starts.
    let pathOfWorktree = Dictionary(uniqueKeysWithValues: worktrees.map { ($0.id, $0.path) })
    for index in sessions.indices where sessions[index].worktreeID != owner[sessions[index].id] {
      let worktree = owner[sessions[index].id]!
      sessions[index].worktreeID = worktree
      // The directory goes with it, as when a tab is moved, or the shell
      // starts in another worktree's checkout.
      if let path = pathOfWorktree[worktree] { sessions[index].workingDirectory = path }
    }

    // A name outliving its worktree returns if one is made at that path
    // again; a blank one draws an empty line over the branch.
    worktreeNames = worktreeNames.filter { id, name in
      worktreeIDs.contains(id) && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    repairGroups()

    if let selected = selectedWorktreeID, !worktreeIDs.contains(selected) {
      selectedWorktreeID = nil
    }
  }

  /// Puts the columns right once the passes above have settled the tabs. A
  /// missing column loses the column, not the tab: one is a layout.
  private mutating func repairGroups() {
    adoptUngroupedTabs()

    // An empty column draws a strip with no tabs over a pane with no
    // terminal, and nothing else here would take it away.
    let occupied = Set(tabs.map(\.groupID))
    tabGroups.removeAll { !occupied.contains($0.id) }

    for index in tabGroups.indices {
      // A width of zero is a column nothing can be laid out in. Decoding
      // makes the same substitution; a half-written save can leave one.
      tabGroups[index].weight = TabGroup.usableWeight(tabGroups[index].weight)
      let tabsHere = tabs(in: tabGroups[index].id)
      if let active = tabGroups[index].activeTabID, tabsHere.contains(where: { $0.id == active }) {
        continue
      }
      // The last tab, where the strip's own fallbacks land: a closed tab
      // hands the column to its neighbour on the right.
      tabGroups[index].activeTabID = tabsHere.last?.id
    }

    // An entry with no columns left, or naming another worktree's, hides
    // the strip of the worktree it names.
    focusedGroupByWorktree = focusedGroupByWorktree.filter { worktreeID, groupID in
      group(groupID)?.worktreeID == worktreeID
    }
    for worktree in Set(tabGroups.map(\.worktreeID)) where focusedGroupByWorktree[worktree] == nil {
      focusedGroupByWorktree[worktree] = groups(in: worktree).first?.id
    }
  }

  /// Gives every tab that names no column one to sit in: a file from before
  /// tab groups, or one whose group was dropped. The first column takes them.
  mutating func adoptUngroupedTabs(activeByWorktree: [Worktree.ID: TerminalTab.ID] = [:]) {
    let known = Dictionary(
      tabGroups.map { ($0.id, $0.worktreeID) }, uniquingKeysWith: { a, _ in a })
    var minted: [Worktree.ID: TabGroup.ID] = [:]

    for index in tabs.indices {
      let tab = tabs[index]
      guard known[tab.groupID] != tab.worktreeID else { continue }

      if let existing = minted[tab.worktreeID] ?? groups(in: tab.worktreeID).first?.id {
        tabs[index].groupID = existing
        continue
      }
      let group = TabGroup(
        worktreeID: tab.worktreeID, activeTabID: activeByWorktree[tab.worktreeID] ?? tab.id)
      tabGroups.append(group)
      minted[tab.worktreeID] = group.id
      tabs[index].groupID = group.id
      if focusedGroupByWorktree[tab.worktreeID] == nil {
        focusedGroupByWorktree[tab.worktreeID] = group.id
      }
    }
  }
}

extension Array {
  fileprivate func uniqued<ID: Hashable>(by id: (Element) -> ID) -> [Element] {
    var seen: Set<ID> = []
    return filter { seen.insert(id($0)).inserted }
  }
}
