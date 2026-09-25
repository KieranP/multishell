import MultishellCore

/// When each worktree was last read and what the read took, for the logs that
/// pace or ration the next read by it.
struct ReadCosts: Sendable {
  private var reads: [Worktree.ID: (at: ContinuousClock.Instant, took: Duration)] = [:]

  /// Whether nothing is held, for the tests.
  var isEmpty: Bool { reads.isEmpty }

  subscript(id: Worktree.ID) -> (at: ContinuousClock.Instant, took: Duration)? { reads[id] }

  mutating func remember(_ costs: [Worktree.ID: Duration]) {
    let finished = ContinuousClock.now
    for (id, took) in costs { reads[id] = (finished, took) }
  }

  mutating func forget(_ gone: some Sequence<Worktree.ID>) {
    for id in gone { reads[id] = nil }
  }

  mutating func removeAll() {
    reads.removeAll()
  }
}
