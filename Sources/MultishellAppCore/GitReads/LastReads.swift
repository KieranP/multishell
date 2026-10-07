import MultishellCore

/// When each worktree was last read and what the read took, for the logs that
/// pace or ration the next read by it.
struct LastReads: Sendable {
  private var reads: [Worktree.ID: (at: ContinuousClock.Instant, duration: Duration)] = [:]

  /// Whether nothing is held, for the tests.
  var isEmpty: Bool { reads.isEmpty }

  subscript(id: Worktree.ID) -> (at: ContinuousClock.Instant, duration: Duration)? { reads[id] }

  mutating func remember(_ costs: [Worktree.ID: Duration]) {
    let finished = ContinuousClock.now
    for (id, duration) in costs { reads[id] = (finished, duration) }
  }

  mutating func forget(_ gone: some Sequence<Worktree.ID>) {
    for id in gone { reads[id] = nil }
  }

  mutating func removeAll() {
    reads.removeAll()
  }
}
