import Foundation
import MultishellCore
import MultishellGitKit

/// What the quick switcher lists for its scope and text; see
/// Docs/design/quick-switcher.md.
extension AppModel {
  private static var placesInAll: Int { 8 }
  private static var filesInAll: Int { 5 }
  private static var commandsInAll: Int { 4 }
  private static var recentListed: Int { 6 }
  private static var agentStates: [SessionState] { [.attention, .failed, .running, .done, .idle] }

  /// Read once a render, as every list here is built afresh.
  public var quickSwitcherResults: QuickSwitcherResults {
    guard let state = quickSwitcher else {
      return QuickSwitcherResults(sections: [], selected: nil)
    }
    let query = QuickSwitcherQuery(state.text)
    let sections: [QuickSwitcherSection] =
      switch state.scope {
      case .all:
        allSections(query, commands: state.commands)

      case .agents:
        agentSections(query)

      case .worktrees:
        [
          QuickSwitcherSection(
            kind: .worktrees,
            items: quickSwitcherRanked(quickSwitcherWorktrees(), by: query),
          )
        ]

      case .tabs:
        [
          QuickSwitcherSection(
            kind: .tabs,
            items: quickSwitcherRanked(quickSwitcherPanesAndFileTabs(), by: query),
          )
        ]

      case .files:
        fileSections(query, limit: Self.quickSwitcherFilesKept)

      case .commands:
        [
          QuickSwitcherSection(
            kind: .commands,
            items: quickSwitcherRanked(quickSwitcherCommands(state.commands), by: query),
          )
        ]
      }
    return QuickSwitcherResults(
      sections: sections.filter { !$0.items.isEmpty },
      selected: state.selected,
      isSelectedByPointer: state.isSelectedByPointer,
      arrowPresses: state.arrowPresses,
      emptyReason: emptyReason(query, in: state.scope),
      query: QuickSwitcherResults.Query(scope: state.scope, text: state.text),
    )
  }

  /// A Files scope, or text in All, over files still being read or listed has
  /// not missed them yet.
  private func emptyReason(
    _ query: QuickSwitcherQuery,
    in scope: QuickSwitcherScope,
  ) -> QuickSwitcherEmptyReason {
    // Read so a read or build ending redraws this, the pending reads and the
    // cache below being unobserved.
    _ = fileTreeBuildLandings
    let listsFiles = scope == .files || (scope == .all && !query.isEmpty)
    if listsFiles, let id = workspace.selectedWorktreeID,
      isReadingQuickSwitcherFiles(of: id, searching: !query.isEmpty)
    {
      return .readingFiles
    }
    return query.isEmpty ? .nothingToList : .noMatch
  }

  /// The first read of its tracked files, or, for a search, the background build
  /// of a large listing; a re-read of a listing already there is no wait.
  private func isReadingQuickSwitcherFiles(of id: Worktree.ID, searching: Bool) -> Bool {
    (trackedFiles[id] == nil && pendingTrackedFilesReads[id] != nil)
      || (searching && fileTreeCache[id]?.awaitsListing == true)
  }

  /// Empty, who is waiting and where the user was; typed, places, then the
  /// selected worktree's files, then commands.
  private func allSections(
    _ query: QuickSwitcherQuery,
    commands: [PlatformMenuItem],
  ) -> [QuickSwitcherSection] {
    guard !query.isEmpty else {
      let waiting = QuickSwitcherSection(kind: .waiting, items: waitingAgents())
      let recent = QuickSwitcherSection(kind: .recent, items: recentWorktrees())
      guard waiting.items.isEmpty, recent.items.isEmpty else { return [waiting, recent] }
      return [QuickSwitcherSection(kind: .worktrees, items: quickSwitcherWorktrees())]
    }
    let places = quickSwitcherPlaces()
    let commandRows = quickSwitcherRanked(quickSwitcherCommands(commands), by: query)
    return [
      QuickSwitcherSection(
        kind: .places,
        items: Array(quickSwitcherRanked(places, by: query).prefix(Self.placesInAll)),
      )
    ]
      + fileSections(query, limit: Self.filesInAll)
      + [
        QuickSwitcherSection(kind: .commands, items: Array(commandRows.prefix(Self.commandsInAll)))
      ]
  }

  /// One section per state, most pressing first.
  private func agentSections(_ query: QuickSwitcherQuery) -> [QuickSwitcherSection] {
    let agents = quickSwitcherAgents()
    let listed = quickSwitcherRanked(agents, by: query)
    return Self.agentStates.map { state in
      let inState = listed.filter { $0.state.shownState == state }
      return QuickSwitcherSection(
        kind: .agents(state),
        items: query.isEmpty
          ? Self.quickSwitcherBySince(inState, in: AgentBoardLane.of(state)) : inState,
      )
    }
  }

  private func waitingAgents() -> [QuickSwitcherItem] {
    Self.quickSwitcherBySince(
      quickSwitcherAgents().filter(Self.isQuickSwitcherWaitingAgent),
      in: .waiting,
    )
  }

  /// `recentWorktreeIDs` drops a worktree as git stops listing it, so each one
  /// left still has a row.
  private func recentWorktrees() -> [QuickSwitcherItem] {
    let recent = recentWorktreeIDs.filter { $0 != worktreeIDInView }
    return quickSwitcherWorktrees(Array(recent.prefix(Self.recentListed)))
  }

  /// The selected worktree's files the text names, or with no text what changed.
  private func fileSections(_ query: QuickSwitcherQuery, limit: Int) -> [QuickSwitcherSection] {
    guard let worktree = workspace.selectedWorktree else { return [] }
    let name = displayName(of: worktree)
    guard !query.isEmpty else {
      // Vetted on the tracked list, not the listing a large repository builds, and
      // held for its first read; one that failed leaves the status alone to go on.
      if trackedFiles[worktree.id] == nil, pendingTrackedFilesReads[worktree.id] != nil {
        return []
      }
      let tracked = trackedFiles[worktree.id] ?? .empty
      var changed = QuickSwitcherBestPaths(limit: limit)
      for change in statuses[worktree.id]?.changes ?? []
      where changed.wouldKeep(change.path, score: 0) && !change.path.hasSuffix("/")
        && !tracked.submodulePaths.contains(change.path)
        && FileTree.isOpenable(change.path, notCheckedOut: tracked.notCheckedOutPaths)
      {
        changed.offer(change.path, score: 0)
      }
      return [
        QuickSwitcherSection(
          kind: .changedFiles(worktreeName: name),
          items: changed.paths.map { quickSwitcherFile($0, in: worktree.id) },
        )
      ]
    }
    // Searched for the Files scope's many either way, so Tab between it and All
    // with the same text answers from the search kept.
    let items = quickSwitcherFileItems(query, in: worktree.id).prefix(limit)
    return [QuickSwitcherSection(kind: .files(worktreeName: name), items: Array(items))]
  }
}
