import MultishellCore

extension AppModel {
  /// A removed worktree's Send state goes with it, the shared picker's included.
  func forgetHandoffState(of gone: Set<Worktree.ID>) {
    for id in gone {
      // A write of nil to a key never set still redraws every reader.
      setIfChanged(\.handoff.recipientPicks[id], nil)
      setIfChanged(\.focusedSessionHistory[id], nil)
      setIfChanged(\.handoff.choices[id], nil)
      setIfChanged(\.handoff.receipts[id], nil)
      setIfChanged(\.handoff.misses[id], nil)
    }
  }
}
