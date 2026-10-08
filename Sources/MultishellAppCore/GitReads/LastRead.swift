/// When one worktree was last read, and what the read took.
struct LastRead: Sendable {
  let at: ContinuousClock.Instant
  let duration: Duration
}
