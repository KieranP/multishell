import MultishellCore

extension AppModel {
  /// Whether there is a pane or a file to find in: the menu's Find… is enabled on it.
  public var findIsAvailable: Bool {
    workspaceTabInView != nil
  }

  /// Whether the menu's target has a bar up, enabling Find Next, Previous and Close
  /// Find. Read off `findBarTargetIDs`, so a menu re-evaluates when it changes.
  public var findIsOpenInView: Bool {
    guard let id = menuFindTarget else { return false }
    return findBarTargetIDs.contains(id)
  }

  /// What the menu's find items act on: a file tab in front, else the bar whose
  /// field has the keyboard, if the tab in front's, else its focused pane.
  private var menuFindTarget: FindTargetID? {
    switch workspaceTabInView {
    case .file(let tab): return tab.id

    case .terminal(let tab):
      if let field = findFieldTargetID, findBarTargetIDs.contains(field),
        tab.sessionIDs.contains(field)
      {
        return field
      }
      return tab.focusedSessionID

    case nil: return nil
    }
  }

  /// A tab in front while the workspace window is key; not under the board
  /// or from a settings window, as with a close.
  private var tabTakesKeystrokes: Bool {
    platform.isWorkspaceWindowKey && workspaceTabInView != nil
  }

  /// What a find keystroke acts on: `menuFindTarget`, but only while there is
  /// a tab in view to take a keystroke.
  private var keystrokeFindTarget: FindTargetID? {
    tabTakesKeystrokes ? menuFindTarget : nil
  }

  /// Cmd+F: a bar on the focused pane of the tab in front, or on its file, or the
  /// field's own bar asked for again, finding the selection or the last find text.
  public func showFind() {
    guard let id = keystrokeFindTarget else { return }
    let wasUp = !findBarTargetIDs.insert(id).inserted
    if let selection = takeSelection(in: id), selection != findText(of: id) {
      replaceFindText(with: selection, in: id, barWasUp: wasUp)
    } else if !wasUp, !findText(of: id).isEmpty {
      search(findText(of: id), in: id)
    }
    findFieldRequests.insert(id)
  }

  /// The pane's or file tab's selection the first time a Cmd+F finds it there,
  /// outliving the find text typed over it; never from the field. terminals.md.
  private func takeSelection(in id: FindTargetID) -> String? {
    guard findFieldTargetID != id else { return nil }
    let selection =
      workspace.fileTab(id) != nil ? fileTabSelections[id] : host.selectionText(of: id)
    guard let text = selection?.withoutTrailingWhitespace else {
      takenFindSelections[id] = nil
      return nil
    }
    guard text.isFindableOnOneLine, text != takenFindSelections[id] else { return nil }
    takenFindSelections[id] = text
    return text
  }

  /// The bar's, once it is on screen: `true` once per Cmd+F, and the field
  /// takes the keyboard on a `true`.
  public func takeFindFieldRequest(_ id: FindTargetID) -> Bool {
    findFieldRequests.remove(id) != nil
  }

  /// The bar's, as its field takes or loses the keyboard.
  public func noteFindField(focused: Bool, of id: FindTargetID) {
    if focused {
      findFieldTargetID = id
    } else if findFieldTargetID == id {
      findFieldTargetID = nil
    }
  }

  public func findText(of id: FindTargetID) -> String {
    findTexts[id] ?? ""
  }

  /// The same text again is nothing: the field commits its binding on
  /// Return, and the engine reads a repeat as a change of nothing.
  public func setFindText(_ text: String, of id: FindTargetID) {
    let searched = findText(of: id)
    guard text != searched else { return }
    findTexts[id] = text
    guard findBarTargetIDs.contains(id) else { return }
    search(text, in: id, replacing: searched)
  }

  /// The command line's: the pane's bar up on `text`, as typing it there.
  func openFind(on text: String, in id: TerminalSession.ID) {
    let wasUp = !findBarTargetIDs.insert(id).inserted
    replaceFindText(with: text, in: id, barWasUp: wasUp)
  }

  /// A bar not up before has no search in the engine for `text` to replace.
  private func replaceFindText(with text: String, in id: FindTargetID, barWasUp: Bool) {
    let searched = findText(of: id)
    findTexts[id] = text
    search(text, in: id, replacing: barWasUp ? searched : nil)
  }

  /// `nil` until the engine has counted; a file's is counted at once.
  public func findMatchCount(of id: FindTargetID) -> FindMatchCount? {
    if workspace.fileTab(id) != nil { return fileFindResults[id]?.matchCount }
    return searchCounts[id]?.matchCount
  }

  /// The engine's count, kept only while the pane has a bar up.
  func noteSearchCount(_ count: TerminalSearchCount, in id: TerminalSession.ID) {
    guard findBarTargetIDs.contains(id) else { return }
    switch count {
    case .total(let total): updateSearchCount(of: id) { $0.noteTotal(total) }
    case .selected(let selected): updateSearchCount(of: id) { $0.noteSelected(selected) }
    }
  }

  /// Written only where it changed: every bar up reads the counts.
  private func updateSearchCount(
    of id: TerminalSession.ID,
    _ change: (inout PaneSearchCount) -> Void,
  ) {
    var count = searchCounts[id] ?? .init()
    change(&count)
    setIfChanged(\.searchCounts[id], count)
  }

  /// `searched` is the text the engine holds, `nil` for none: one equal but for
  /// ASCII case it skips, so its count and selected match stand.
  private func search(_ text: String, in id: FindTargetID, replacing searched: String? = nil) {
    if workspace.fileTab(id) != nil {
      runFileFind(for: text, in: id)
      return
    }
    if searched.map({ !$0.isSameSearchText(as: text) }) ?? true {
      setIfChanged(
        \.searchCounts[id],
        PaneSearchCount.forNewSearch(
          after: searchCounts[id],
          endingOne: searched?.isEmpty == false,
        ),
      )
      steppedFindTargetIDs.remove(id)
    }
    host.search(.find(text), in: id)
  }

  /// The menu's, on the field's bar where one has the keyboard, else the tab in
  /// view's; none up, nothing. Another target's bar, hidden by a switch, stays.
  public func findNext() { stepKeystrokeFindTarget(.next) }
  public func findPrevious() { stepKeystrokeFindTarget(.previous) }

  /// Cmd+Shift+F, from the pane, where Escape reaches the program, or from a
  /// field: that one bar goes down and no other.
  public func closeFind() {
    guard let id = keystrokeFindTarget else { return }
    closeFind(in: id)
  }

  /// A bar's own Return and arrows, which act on its own target whatever has
  /// the keyboard.
  public func findNext(in id: FindTargetID) { step(.next, in: id) }
  public func findPrevious(in id: FindTargetID) { step(.previous, in: id) }

  private func stepKeystrokeFindTarget(_ direction: CycleDirection) {
    guard let id = keystrokeFindTarget else { return }
    step(direction, in: id)
  }

  /// The first step after a new find text lands nearest the prompt whichever arrow
  /// asked: the engine selected nothing on the find text. See terminals.md.
  private func step(_ direction: CycleDirection, in id: FindTargetID) {
    guard findBarTargetIDs.contains(id), !findText(of: id).isEmpty else { return }
    if workspace.fileTab(id) != nil {
      stepFileFind(direction, in: id)
      return
    }
    // The engine says the match it lands on a turn later, and nothing for a
    // step back onto the only match, which stays selected; terminals.md.
    if let count = searchCounts[id], count.total != 1 {
      updateSearchCount(of: id) { $0.noteStep() }
    }
    let engineStep: TerminalSearch = direction == .next ? .next : .previous
    host.search(steppedFindTargetIDs.insert(id).inserted ? .nearest : engineStep, in: id)
  }

  /// Escape or the close: the keyboard goes to the bar's own target, not the
  /// focused one, as clicking into a field moved the store's focus nowhere.
  public func closeFind(in id: FindTargetID) {
    guard endFind(in: id) else { return }
    if workspace.fileTab(id) != nil { fileTabFocusRequest = id } else { host.focus(id) }
  }

  /// The bar down with the keyboard left where it was, as the command line
  /// closes it. `false` where there was no bar.
  @discardableResult
  func endFind(in id: FindTargetID) -> Bool {
    guard findBarTargetIDs.remove(id) != nil else { return false }
    steppedFindTargetIDs.remove(id)
    setIfChanged(\.searchCounts[id], nil)
    // The torn-down field may never say it lost the keyboard.
    if findFieldTargetID == id { findFieldTargetID = nil }
    if workspace.fileTab(id) != nil {
      setIfChanged(\.fileFindResults[id], nil)
      // The count starts over, so what a dropped view drew no longer compares.
      fileFindsShown[id] = nil
    } else {
      host.search(.end, in: id)
    }
    return true
  }

  /// Bars and find texts whose pane or file tab has gone. From the reconcile, as
  /// `prunePendingClose` is, and from a shell exiting, which closes its session.
  func pruneFind() {
    let existingTargetIDs = Set(workspace.sessions.map(\.id) + workspace.fileTabs.map(\.id))
    setIfChanged(\.fileFindResults, fileFindResults.filter { existingTargetIDs.contains($0.key) })
    setIfChanged(\.findBarTargetIDs, findBarTargetIDs.filter(existingTargetIDs.contains))
    setIfChanged(\.findTexts, findTexts.filter { existingTargetIDs.contains($0.key) })
    setIfChanged(\.findFieldRequests, findFieldRequests.filter(existingTargetIDs.contains))
    steppedFindTargetIDs = steppedFindTargetIDs.filter(existingTargetIDs.contains)
    setIfChanged(\.searchCounts, searchCounts.filter { existingTargetIDs.contains($0.key) })
    setIfChanged(
      \.takenFindSelections,
      takenFindSelections.filter { existingTargetIDs.contains($0.key) },
    )
    if let field = findFieldTargetID, !existingTargetIDs.contains(field) {
      findFieldTargetID = nil
    }
  }
}
