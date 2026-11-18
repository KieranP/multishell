extension DebugMemoryRow: DebugSortableRow {
  /// Its source after the title, as two tabs can share one.
  var sortName: String { "\(title)\u{0}\(source)" }

  /// The app and Other processes have no worktree, so they sort last under it.
  func sortKey(by column: DebugMemoryColumn) -> DebugSortKey? {
    switch column {
    case .name: .text(title)
    case .processCount: processCount.map { .number(Double($0)) }
    case .selfMemory: selfMemory.map { .number(Double($0)) }
    case .totalMemory: totalMemory.map { .number(Double($0)) }
    case .worktree: if case .tab = source { .text(subtitle) } else { nil }
    }
  }
}
