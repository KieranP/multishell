import MultishellCore

extension AppModel {
  /// Cmd+F: a bar on the focused pane of the tab in front, or the field's own
  /// bar asked for again. A needle typed there before is searched again.
  public func showFind() {
    guard paneInView != nil, let id = menuFindPane else { return }
    if findingSessionIDs.insert(id).inserted, !findText(of: id).isEmpty {
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
      findFieldPane = id
    } else if findFieldPane == id {
      findFieldPane = nil
    }
  }

  public func findText(of id: TerminalSession.ID) -> String {
    findNeedles[id] ?? ""
  }

  /// The same text again is nothing: the field commits its binding on
  /// Return, and the engine reads a repeat as a change of nothing.
  public func setFindText(_ text: String, of id: TerminalSession.ID) {
    guard text != findText(of: id) else { return }
    findNeedles[id] = text
    guard findingSessionIDs.contains(id) else { return }
    search(text, in: id)
  }

  /// A needle selects nothing in the engine, so the next step starts over.
  private func search(_ text: String, in id: TerminalSession.ID) {
    findSelections.remove(id)
    host.search(.find(text), in: id)
  }

  /// Whether there is a pane to find in: the menu's Find… is enabled on it.
  public var findIsAvailable: Bool {
    guard let worktree = worktreeInView?.id else { return false }
    return workspace.activeTab(in: worktree) != nil
  }

  /// Whether the menu's pane has a bar up, enabling Find Next, Previous and Close
  /// Find. Read off the workspace, so a menu re-evaluates when it changes.
  public var findIsOpenInView: Bool {
    guard let id = menuFindPane else { return false }
    return findingSessionIDs.contains(id)
  }

  /// The menu's, on the field's bar where one has the keyboard, else the pane in
  /// view's; none up, nothing. Another pane's bar, hidden by a switch, stays.
  public func findNext() { navigateFind(.next) }
  public func findPrevious() { navigateFind(.previous) }

  /// Cmd+Shift+F, from the pane, where Escape reaches the program, or from a
  /// field: that one bar goes down and no other.
  public func closeFind() {
    guard paneInView != nil, let id = menuFindPane else { return }
    closeFind(in: id)
  }

  /// A bar's own Return and arrows, which act on its pane whichever pane
  /// has the keyboard.
  public func findNext(in id: TerminalSession.ID) { step(.next, in: id) }
  public func findPrevious(in id: TerminalSession.ID) { step(.previous, in: id) }

  private func navigateFind(_ direction: TerminalSearch) {
    guard paneInView != nil, let id = menuFindPane else { return }
    step(direction, in: id)
  }

  /// The first step after a needle lands nearest the prompt whichever arrow
  /// asked: the engine selected nothing on the needle. See terminals.md.
  private func step(_ direction: TerminalSearch, in id: TerminalSession.ID) {
    guard findingSessionIDs.contains(id), !findText(of: id).isEmpty else { return }
    host.search(findSelections.insert(id).inserted ? .nearest : direction, in: id)
  }

  /// Escape or the close: the keyboard goes to the bar's own pane, not the focused
  /// one, since clicking into a field moved the store's focus nowhere; terminals.md.
  public func closeFind(in id: TerminalSession.ID) {
    guard findingSessionIDs.remove(id) != nil else { return }
    findSelections.remove(id)
    // The torn-down field may never say it lost the keyboard.
    if findFieldPane == id { findFieldPane = nil }
    host.search(.end, in: id)
    host.focus(id)
  }

  /// The pane a find keystroke acts on: the bar whose field has the keyboard,
  /// if it is one of the tab in front's, else the focused pane.
  private var menuFindPane: TerminalSession.ID? {
    guard let worktree = worktreeInView?.id, let tab = workspace.activeTab(in: worktree)
    else { return nil }
    if let field = findFieldPane, findingSessionIDs.contains(field), tab.sessionIDs.contains(field)
    {
      return field
    }
    return tab.focusedSessionID
  }

  /// The focused pane of the tab in front; none under the board or from a
  /// settings window, as with a close. Every find keystroke asks it first.
  private var paneInView: TerminalSession.ID? {
    guard platform.workspaceWindowIsKey, let worktree = worktreeInView?.id else { return nil }
    return workspace.activeTab(in: worktree)?.focusedSessionID
  }

  /// Bars and needles whose pane has gone. From the reconcile, as `pruneTabPrompts`
  /// is, and from a shell exiting, which closes its session without one.
  func pruneFind() {
    setIfChanged(\.findingSessionIDs, findingSessionIDs.filter { workspace.session($0) != nil })
    setIfChanged(\.findNeedles, findNeedles.filter { workspace.session($0.key) != nil })
    setIfChanged(\.findFieldRequests, findFieldRequests.filter { workspace.session($0) != nil })
    findSelections = findSelections.filter { workspace.session($0) != nil }
    if let field = findFieldPane, workspace.session(field) == nil { findFieldPane = nil }
  }
}
