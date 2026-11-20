import MultishellCore

extension AppModel {
  public func focusNextPane() { focusAdjacentPane(.next) }
  public func focusPreviousPane() { focusAdjacentPane(.previous) }

  /// In reading order, left to right and top to bottom, wrapping at either end
  /// as `focusAdjacentGroup` does.
  private func focusAdjacentPane(_ direction: CycleDirection) {
    guard let tab = tabInView,
      let next = tab.root.sessionIDs.neighbour(ofValue: tab.focusedSessionID, direction)
    else { return }
    show(pane: next)
  }
}
