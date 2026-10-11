import MultishellCore

extension AppModel {
  /// The bar's own field, Return and arrows, and close, on that pane; the
  /// answer is the pane, whose `find` the engine fills in as it counts.
  func answerFindInPane(_ action: PaneFindAction, in id: TerminalSession.ID) -> ControlReply {
    if let refusal = refusalToReachLivePane(id) { return .refused(refusal) }
    if let refusal = refusalToFind(action, in: id) { return .refused(refusal) }
    switch action {
    case .search(let text): openFind(on: text, in: id)
    case .next: findNext(in: id)
    case .previous: findPrevious(in: id)
    case .close: endFind(in: id)
    }
    return answerDescribePane(id)
  }

  /// A search needs text; the rest need the bar open, and a step its text.
  private func refusalToFind(
    _ action: PaneFindAction,
    in id: TerminalSession.ID,
  ) -> ControlRefusal? {
    if case .search(let text) = action {
      return text.isEmpty ? .noFindText(id: id) : nil
    }
    guard findBarSessionIDs.contains(id) else { return .noFindBar(id: id) }
    if action != .close, findText(of: id).isEmpty { return .noFindText(id: id) }
    return nil
  }
}
