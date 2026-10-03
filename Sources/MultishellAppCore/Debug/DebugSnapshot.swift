/// What the debug panel draws from at one moment, held still while paused.
struct DebugSnapshot: Sendable, Equatable {
  let history: DebugHistory
  let attribution: PaneProcessAttribution
}
