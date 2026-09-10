import Foundation

extension Workspace {
  /// Restores the invariants the store maintains between its collections
  /// after state comes off disk, where a crash mid-save, a hand edit or a bug
  /// in an earlier build can leave them broken.
  ///
  /// A session in no tab would otherwise be given a live shell that nothing
  /// displays and nothing can close; a tab whose active entry is missing
  /// hides the whole tab strip.
  public mutating func repairReferences() {
    // The store never adds an identity twice, but a file can hold one twice:
    // a hand edit, or two spellings of one path that normalise together.
    // Every view keys on identity, and a repeat would trap the first
    // dictionary built from it. The first entry is the one kept.
    projects = projects.uniqued(by: \.id)
    worktrees = worktrees.uniqued(by: \.id)
    sessions = sessions.uniqued(by: \.id)
    tabGroups = tabGroups.uniqued(by: \.id)

    let projectIDs = Set(projects.map(\.id))
    worktrees.removeAll { !projectIDs.contains($0.projectID) }
    let worktreeIDs = Set(worktrees.map(\.id))
    tabs.removeAll { !worktreeIDs.contains($0.worktreeID) }
    tabGroups.removeAll { !worktreeIDs.contains($0.worktreeID) }

    // One pass over every pane in display order drops panes whose session is
    // missing and second appearances of a session, in this tab or an earlier
    // one, and collapses the splits that leaves too small. A session shown
    // twice would be given one shell and two views fighting over it.
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
    // A session belongs to the worktree of the tab that shows it, and the
    // store writes the two together. A file where they disagree gets the
    // tab's answer: it is what the sidebar lists the tab under, and what
    // decides whether the session's shell is started at all.
    let pathOfWorktree = Dictionary(uniqueKeysWithValues: worktrees.map { ($0.id, $0.path) })
    for index in sessions.indices where sessions[index].worktreeID != owner[sessions[index].id] {
      let worktree = owner[sessions[index].id]!
      sessions[index].worktreeID = worktree
      // The directory goes with it, as it does when a tab is moved: a
      // session left pointing into another worktree would start this
      // project's shell in that one's checkout.
      if let path = pathOfWorktree[worktree] { sessions[index].workingDirectory = path }
    }

    // A name whose worktree is gone would come back if a worktree were
    // ever made at that path again, and a blank one would draw an empty
    // first line over the branch.
    worktreeNames = worktreeNames.filter { id, name in
      worktreeIDs.contains(id) && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    repairGroups()

    if let selected = selectedWorktreeID, !worktreeIDs.contains(selected) {
      selectedWorktreeID = nil
    }
  }

  /// Puts the columns right, after the passes above have settled which tabs
  /// there are. A tab whose column is missing keeps its tab rather than
  /// being dropped: the column is a layout, and the tab is a shell.
  private mutating func repairGroups() {
    adoptUngroupedTabs()

    // A column with nothing in it draws a strip with no tabs and a pane
    // with no terminal, and nothing but this would ever take it away: the
    // store removes one the moment its last tab leaves.
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
      // The last tab of the column, which is where the strip's own
      // fallbacks land: a closed tab hands the column over to its neighbour
      // on the right.
      tabGroups[index].activeTabID = tabsHere.last?.id
    }

    // An entry for a worktree with no columns left, or one naming a column
    // that belongs to another worktree, would hide the strip of the
    // worktree it names.
    focusedGroupByWorktree = focusedGroupByWorktree.filter { worktreeID, groupID in
      group(groupID)?.worktreeID == worktreeID
    }
    for worktree in Set(tabGroups.map(\.worktreeID)) where focusedGroupByWorktree[worktree] == nil {
      focusedGroupByWorktree[worktree] = groups(in: worktree).first?.id
    }
  }

  /// Gives every tab that names no column a column to sit in.
  ///
  /// This is what a state file written before tab groups existed goes
  /// through: none of its tabs names a group, so each worktree's tabs are
  /// gathered into the one column they were saved as, showing whichever tab
  /// `activeByWorktree` says was active. It is also the safety net for a
  /// file whose group decoded badly and was dropped, or one hand-edited: the
  /// worktree's first column takes the orphans rather than a new column
  /// appearing beside it.
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
