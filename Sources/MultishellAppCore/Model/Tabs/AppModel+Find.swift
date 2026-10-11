import MultishellCore

extension AppModel {
  /// Whether there is a pane to find in: the menu's Find… is enabled on it.
  public var findIsAvailable: Bool {
    tabInView != nil
  }

  /// Whether the menu's pane has a bar up, enabling Find Next, Previous and Close
  /// Find. Read off `findBarSessionIDs`, so a menu re-evaluates when it changes.
  public var findIsOpenInView: Bool {
    guard let id = menuFindPane else { return false }
    return findBarSessionIDs.contains(id)
  }

  /// The pane the menu's find items act on, whichever window is key: the bar
  /// whose field has the keyboard, if it is one of the tab in front's, else its focused pane.
  private var menuFindPane: TerminalSession.ID? {
    guard let tab = tabInView else { return nil }
    if let field = findFieldSessionID, findBarSessionIDs.contains(field),
      tab.sessionIDs.contains(field)
    {
      return field
    }
    return tab.focusedSessionID
  }

  /// A tab in front while the workspace window is key; not under the board
  /// or from a settings window, as with a close.
  private var paneTakesKeystrokes: Bool {
    platform.workspaceWindowIsKey && tabInView != nil
  }

  /// The pane a find keystroke acts on: `menuFindPane`, but only while there is
  /// a pane in view to take a keystroke.
  private var keystrokeFindPane: TerminalSession.ID? {
    paneTakesKeystrokes ? menuFindPane : nil
  }

  /// Cmd+F: a bar on the focused pane of the tab in front, or the field's own
  /// bar asked for again. Find text typed there before is searched again.
  public func showFind() {
    guard let id = keystrokeFindPane else { return }
    if findBarSessionIDs.insert(id).inserted, !findText(of: id).isEmpty {
      search(findText(of: id), in: id)
    }
    findFieldRequests.insert(id)
  }

  /// The bar's, once it is on screen: `true` once per Cmd+F, and the field
  /// takes the keyboard on a `true`.
  public func takeFindFieldRequest(_ id: TerminalSession.ID) -> Bool {
    findFieldRequests.remove(id) != nil
  }

  /// The bar's, as its field takes or loses the keyboard.
  public func noteFindField(focused: Bool, of id: TerminalSession.ID) {
    if focused {
      findFieldSessionID = id
    } else if findFieldSessionID == id {
      findFieldSessionID = nil
    }
  }

  public func findText(of id: TerminalSession.ID) -> String {
    findTexts[id] ?? ""
  }

  /// The same text again is nothing: the field commits its binding on
  /// Return, and the engine reads a repeat as a change of nothing.
  public func setFindText(_ text: String, of id: TerminalSession.ID) {
    let searched = findText(of: id)
    guard text != searched else { return }
    findTexts[id] = text
    guard findBarSessionIDs.contains(id) else { return }
    search(text, in: id, replacing: searched)
  }

  /// The command line's: the pane's bar up on `text`, as typing it there.
  func openFind(on text: String, in id: TerminalSession.ID) {
    let wasUp = !findBarSessionIDs.insert(id).inserted
    let searched = findText(of: id)
    findTexts[id] = text
    search(text, in: id, replacing: wasUp ? searched : nil)
  }

  /// The engine's count, kept only while the pane has a bar up.
  func noteSearchCount(_ count: TerminalSearchCount, in id: TerminalSession.ID) {
    guard findBarSessionIDs.contains(id) else { return }
    switch count {
    case .total(let total): searchCounts[id, default: .init()].total = total
    case .selected(let selected): searchCounts[id, default: .init()].selected = selected
    }
  }

  /// `searched` is the text the engine holds, `nil` for none: one equal but for
  /// ASCII case it skips, so its count and selection stand.
  private func search(_ text: String, in id: TerminalSession.ID, replacing searched: String? = nil)
  {
    if searched.map({ !$0.isSameSearchText(as: text) }) ?? true {
      searchCounts[id] = nil
      steppedFindSessionIDs.remove(id)
    }
    host.search(.find(text), in: id)
  }

  /// The menu's, on the field's bar where one has the keyboard, else the pane in
  /// view's; none up, nothing. Another pane's bar, hidden by a switch, stays.
  public func findNext() { stepKeystrokeFindPane(.next) }
  public func findPrevious() { stepKeystrokeFindPane(.previous) }

  /// Cmd+Shift+F, from the pane, where Escape reaches the program, or from a
  /// field: that one bar goes down and no other.
  public func closeFind() {
    guard let id = keystrokeFindPane else { return }
    closeFind(in: id)
  }

  /// A bar's own Return and arrows, which act on its pane whichever pane
  /// has the keyboard.
  public func findNext(in id: TerminalSession.ID) { step(.next, in: id) }
  public func findPrevious(in id: TerminalSession.ID) { step(.previous, in: id) }

  private func stepKeystrokeFindPane(_ direction: TerminalSearch) {
    guard let id = keystrokeFindPane else { return }
    step(direction, in: id)
  }

  /// The first step after a new find text lands nearest the prompt whichever arrow
  /// asked: the engine selected nothing on the find text. See terminals.md.
  private func step(_ direction: TerminalSearch, in id: TerminalSession.ID) {
    guard findBarSessionIDs.contains(id), !findText(of: id).isEmpty else { return }
    // The engine says the match it lands on a turn later, and nothing for a
    // step back onto the only match, whose selection stands; terminals.md.
    if searchCounts[id]?.total != 1 { searchCounts[id]?.selected = nil }
    host.search(steppedFindSessionIDs.insert(id).inserted ? .nearest : direction, in: id)
  }

  /// Escape or the close: the keyboard goes to the bar's own pane, not the focused
  /// one, since clicking into a field moved the store's focus nowhere; terminals.md.
  public func closeFind(in id: TerminalSession.ID) {
    guard endFind(in: id) else { return }
    host.focus(id)
  }

  /// The bar down with the keyboard left where it was, as the command line
  /// closes it. `false` where there was no bar.
  @discardableResult
  func endFind(in id: TerminalSession.ID) -> Bool {
    guard findBarSessionIDs.remove(id) != nil else { return false }
    steppedFindSessionIDs.remove(id)
    searchCounts[id] = nil
    // The torn-down field may never say it lost the keyboard.
    if findFieldSessionID == id { findFieldSessionID = nil }
    host.search(.end, in: id)
    return true
  }

  /// Bars and find texts whose pane has gone. From the reconcile, as `prunePendingClose`
  /// is, and from a shell exiting, which closes its session without one.
  func pruneFind() {
    let existingSessionIDs = Set(workspace.sessions.map(\.id))
    setIfChanged(\.findBarSessionIDs, findBarSessionIDs.filter(existingSessionIDs.contains))
    setIfChanged(\.findTexts, findTexts.filter { existingSessionIDs.contains($0.key) })
    setIfChanged(\.findFieldRequests, findFieldRequests.filter(existingSessionIDs.contains))
    steppedFindSessionIDs = steppedFindSessionIDs.filter(existingSessionIDs.contains)
    searchCounts = searchCounts.filter { existingSessionIDs.contains($0.key) }
    if let field = findFieldSessionID, !existingSessionIDs.contains(field) {
      findFieldSessionID = nil
    }
  }
}
