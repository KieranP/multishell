import MultishellCore

/// A state landing on a pane's entry, from a report or from program status.
extension SessionStates {
  /// A finished state lands unless the user is looking and looking clears
  /// it; the process it was about is dropped either way.
  mutating func landFinished(_ state: SessionState, on key: Key, isSeen: Bool) {
    update(key) { stored in
      stored.state = isSeen && state.clearsWhenSeen ? nil : state
      stored.pid = nil
    }
  }

  /// Working or Waiting is about a process: a report naming none leaves the
  /// one an earlier report named.
  mutating func landUnderway(_ state: SessionState, pid: Int32?, on key: Key) {
    update(key) { stored in
      stored.state = state
      if let pid { stored.pid = pid }
    }
  }

  /// Only where a state survived: a Done about a tab the user is looking at
  /// leaves nothing to say something about.
  mutating func noteIfStanding(_ note: SessionNote, on key: Key) {
    guard entries[key]?.state != nil else { return }
    update(key) { $0.note = note }
  }
}
