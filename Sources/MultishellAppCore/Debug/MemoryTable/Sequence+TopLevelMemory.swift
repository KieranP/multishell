extension Sequence<DebugProcessRow> {
  /// What the processes at the top of each tree hold themselves, which is a
  /// tab's own share before what its shells started.
  var topLevelMemory: UInt64 { filter { $0.depth == 0 }.reduce(0) { $0 + $1.selfMemory } }
}
