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
    openQuickSwitcher(scope)
  }

  /// Up over the workspace window whichever window has the keyboard, which
  /// only the keys check: a request comes from no window.
  func openQuickSwitcher(_ scope: QuickSwitcherScope) {
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
    chooseQuickSwitcherRow(target, as: .click)
  }

  /// A click takes a menu item on the menu's own turn and beeps at a row leading
  /// nowhere; a request has the menu validate the item, and is answered.
  @discardableResult
  func chooseQuickSwitcherRow(
    _ target: QuickSwitcherTarget,
    as asker: Asker,
  ) -> QuickSwitcherChoice {
    // A request is told what the menu would say of the item before anything closes.
    if case .command(let path) = target, asker == .request {
      let item = platform.menuItems.first { $0.path == path }
      if item?.isEnabled != true {
        return .menuItemRefused(path: path, item == nil ? .notFound : .disabled)
      }
    }
    guard dismissQuickSwitcher() else { return .notUp }
    switch target {
    case .command(let path):
      focusActivePane()
      // On the menu's own turn, once the field has let the keyboard go; a request's
      // as the command line's, and answered once it has run.
      guard asker == .request else {
        platform.chooseMenuItem(path)
        return .done
      }
      let platform = self.platform
      return .menuItem(path: path, Task { await platform.performMenuItemOnItsTurn(path) })

    case .file(let path, let worktreeID):
      let opening = chooseFileRow(path, in: worktreeID, as: asker)
      return .openingFile(path: path, worktree: worktreeID, opening)

    case .fileTab(let id):
      return goTo(worktreeChosen(by: target), as: asker) { store.activateTab(id) }

    case .pane(let id):
      return goTo(worktreeChosen(by: target), as: asker) { store.focusSession(id) }

    case .project(let id)
    where workspace.project(id) != nil && preferredWorktree(ofProject: id) == nil:
      if asker == .click { platform.beep() }
      focusActivePane()
      return .projectWithNoWorktree(id)

    case .project, .worktree:
      return goTo(worktreeChosen(by: target), as: asker)
    }
  }

  /// Where a row leads, `nil` where that has gone since it was listed; a
  /// command leads to no worktree.
  private func worktreeChosen(by target: QuickSwitcherTarget) -> Worktree? {
    switch target {
    case .command: nil
    case .file(_, let worktreeID): workspace.worktree(worktreeID)
    case .fileTab(let id): workspace.fileTab(id).flatMap { workspace.worktree($0.worktreeID) }
    case .pane(let id): workspace.session(id).flatMap { workspace.worktree($0.worktreeID) }
    case .project(let id): preferredWorktree(ofProject: id)
    case .worktree(let id): workspace.worktree(id)
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
  private func goTo(
    _ worktree: Worktree?,
    as asker: Asker,
    turning turn: () -> Void = {},
  ) -> QuickSwitcherChoice {
    guard let worktree else {
      if asker == .click { platform.beep() }
      focusActivePane()
      return .rowGone
    }
    guard select(worktree, openingFirstTab: .onSelect, turning: turn) else {
      focusActivePane()
      return .worktreeNotReady(worktree.id)
    }
    expandProject(holding: worktree)
    return .done
  }

  /// The project's worktree turned to last, else its main one.
  private func preferredWorktree(ofProject id: Project.ID) -> Worktree? {
    let worktrees = workspace.worktrees(of: id)
    let recent = recentWorktreeIDs.lazy.compactMap { recentID in
      worktrees.first { $0.id == recentID }
    }.first
    return recent ?? worktrees.first(where: \.isPrimary) ?? worktrees.first
  }

  /// A file row chosen, once the switcher is down: the keyboard back on the pane
  /// at once, and the file's tab once read, `nil` where it would not open.
  private func chooseFileRow(
    _ path: String,
    in worktreeID: Worktree.ID,
    as asker: Asker,
  ) -> Task<FileTab?, Never> {
    focusActivePane()
    let coverChosenOver = detailCover
    return Task { await openChosenFile(path, in: worktreeID, over: coverChosenOver, as: asker) }
  }

  /// Its project opened, and the cover it was chosen over taken down.
  private func openChosenFile(
    _ path: String,
    in worktreeID: Worktree.ID,
    over coverChosenOver: DetailCover?,
    as asker: Asker,
  ) async -> FileTab? {
    let opened = await openFileAsTab(path, in: worktreeID, as: asker)
    if opened != nil, let worktree = workspace.worktree(worktreeID) {
      expandProject(holding: worktree)
    }
    // The cover it was chosen over comes down once it opens, without the
    // first tab or trust question a select asks; one raised since stays.
    if opened != nil, coverChosenOver != nil, detailCover == coverChosenOver {
      uncoverDetailAndReadItsTabs()
      focusActivePane()
    }
    // After the cover comes down, so the panel it hid keeps the listing it shows.
    forgetUnreadPanelListings()
    return opened
  }
}
