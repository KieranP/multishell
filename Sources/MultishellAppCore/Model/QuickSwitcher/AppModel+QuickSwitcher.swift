import MultishellCore

/// The quick switcher's keys and clicks; what it lists is in
/// `AppModel+QuickSwitcherSections`. See Docs/design/quick-switcher.md.
extension AppModel {
  /// Two items of the same titles, "…" or not, are one path, which only ever
  /// chooses the first, so a later one is never listed, nor the first if greyed out.
  private static func choosableCommands(_ items: [PlatformMenuItem]) -> [PlatformMenuItem] {
    var seen = Set<[String]>()
    return items.filter { item in
      seen.insert(item.path.map(\.withoutTrailingEllipsis)).inserted && item.isEnabled
        && !(item.path.last ?? "").isEmpty
    }
  }

  /// Cmd+P and Shift+Cmd+P. Its own key again closes it; the other key
  /// changes its scope.
  public func toggleQuickSwitcher(_ scope: QuickSwitcherScope) {
    guard platform.isWorkspaceWindowKey else { return }
    if let open = quickSwitcher {
      if open.scope == scope {
        closeQuickSwitcher()
      } else {
        setQuickSwitcherScope(scope)
      }
      return
    }
    quickSwitcher = QuickSwitcherState(
      scope: scope,
      commands: Self.choosableCommands(platform.commandMenuItems),
    )
    readQuickSwitcherFilesOnceListed()
  }

  /// Its field losing the keyboard to another, a find bar's or a pane's: it
  /// closes, leaving the keyboard where it went.
  public func noteQuickSwitcherFieldEndedEditing() {
    dismissQuickSwitcher()
  }

  /// Escape, or a click outside it, which hands the keyboard back to the pane;
  /// over a cover there is none, nor was one before it opened.
  public func closeQuickSwitcher() {
    guard dismissQuickSwitcher() else { return }
    focusActivePane()
  }

  /// A `>` typed into the empty field, as an editor's palette takes it, turns
  /// All to Commands; one carried into All by Tab stays text.
  public func setQuickSwitcherText(_ text: String) {
    guard var state = quickSwitcher, state.text != text else { return }
    if state.scope == .all, state.text.isEmpty, text.hasPrefix(">") {
      state.scope = .commands
      state.text = String(text.dropFirst())
    } else {
      state.text = text
    }
    state.selected = nil
    quickSwitcher = state
    readQuickSwitcherFilesOnceListed()
  }

  /// Backspace with nothing left to delete: back to All, so a `>` typed by
  /// mistake is undone as an editor's palette undoes it.
  public func backspaceInEmptyQuickSwitcherField() {
    setQuickSwitcherScope(.all)
  }

  public func setQuickSwitcherScope(_ scope: QuickSwitcherScope) {
    guard quickSwitcher != nil, quickSwitcher?.scope != scope else { return }
    quickSwitcher?.scope = scope
    quickSwitcher?.selected = nil
    readQuickSwitcherFilesOnceListed()
  }

  /// Tab and Shift+Tab.
  public func stepQuickSwitcherScope(_ direction: CycleDirection) {
    guard let scope = quickSwitcher?.scope,
      let stepped = QuickSwitcherScope.allCases.neighbour(of: scope, direction)
    else { return }
    setQuickSwitcherScope(stepped)
  }

  /// The arrow keys, stopping at either end.
  public func moveQuickSwitcherSelection(_ direction: CycleDirection) {
    let results = quickSwitcherResults
    let rows = results.rows
    guard !rows.isEmpty else { return }
    let current = results.selection.flatMap(rows.firstIndex(of:)) ?? 0
    let next = direction == .next ? min(current + 1, rows.count - 1) : max(current - 1, 0)
    quickSwitcher?.selected = rows[next]
    quickSwitcher?.isSelectedByPointer = false
    quickSwitcher?.arrowPresses += 1
  }

  /// The pointer moving over a row selects it, so only one row is ever lit.
  public func pointQuickSwitcherAt(_ target: QuickSwitcherTarget) {
    guard quickSwitcher != nil, quickSwitcher?.selected != target else { return }
    quickSwitcher?.selected = target
    quickSwitcher?.isSelectedByPointer = true
  }

  /// Return, on the row selected as the key lands, so keys typed in a burst act
  /// in order; see quick-switcher.md.
  public func chooseSelectedQuickSwitcherRow() {
    guard let target = quickSwitcherResults.selection else { return }
    chooseQuickSwitcherRow(target)
  }

  /// The row selected is no longer listed: the first takes its place for good,
  /// so a report listing it again does not move the highlight off screen.
  public func forgetLostQuickSwitcherSelection() {
    guard let selected = quickSwitcher?.selected,
      !quickSwitcherResults.rows.contains(selected)
    else { return }
    quickSwitcher?.selected = nil
    quickSwitcher?.isSelectedByPointer = false
  }

  /// A click on a row.
  public func chooseQuickSwitcherRow(_ target: QuickSwitcherTarget) {
    guard dismissQuickSwitcher() else { return }
    switch target {
    case .command(let path):
      focusActivePane()
      platform.chooseMenuItem(path)

    case .file(let path, let worktreeID):
      focusActivePane()
      let coverChosenOver = detailCover
      Task {
        let opened = await openFileAsTab(path, in: worktreeID)
        if opened, let worktree = workspace.worktree(worktreeID) {
          expandProject(holding: worktree)
        }
        // The cover it was chosen over comes down once it opens, without the
        // first tab or trust question a select asks; one raised since stays.
        if opened, coverChosenOver != nil, detailCover == coverChosenOver {
          uncoverDetailAndReadItsTabs()
          focusActivePane()
        }
        // The open read the file tree again, after the dismiss let it go.
        forgetUnreadPanelListings()
      }

    case .fileTab(let id):
      let worktree = workspace.fileTab(id).flatMap { workspace.worktree($0.worktreeID) }
      goTo(worktree) { store.activateTab(id) }

    case .pane(let id):
      let worktree = workspace.session(id).flatMap { workspace.worktree($0.worktreeID) }
      goTo(worktree) { store.focusSession(id) }

    case .project(let id):
      guard let worktree = preferredWorktree(ofProject: id) else {
        platform.beep()
        focusActivePane()
        return
      }
      goTo(worktree)

    case .worktree(let id):
      goTo(workspace.worktree(id))
    }
  }

  /// Takes it down and lets go of a file listing only it wanted; also as
  /// anything else hands a pane the keyboard, which would leave it drawn.
  @discardableResult
  func dismissQuickSwitcher() -> Bool {
    guard quickSwitcher != nil else { return false }
    quickSwitcher = nil
    forgetQuickSwitcherFileSearches()
    forgetUnreadPanelListings()
    return true
  }

  /// Its project opens in the sidebar so its row shows. A worktree that cannot
  /// be selected leaves the keyboard where it was; one gone since beeps.
  private func goTo(_ worktree: Worktree?, turning turn: () -> Void = {}) {
    guard let worktree, select(worktree, openingFirstTab: .onSelect, turning: turn)
    else {
      if worktree == nil { platform.beep() }
      focusActivePane()
      return
    }
    expandProject(holding: worktree)
  }

  /// The project's worktree turned to last, else its main one.
  private func preferredWorktree(ofProject id: Project.ID) -> Worktree? {
    let worktrees = workspace.worktrees(of: id)
    let recent = recentWorktreeIDs.lazy.compactMap { recentID in
      worktrees.first { $0.id == recentID }
    }.first
    return recent ?? worktrees.first(where: \.isPrimary) ?? worktrees.first
  }
}
