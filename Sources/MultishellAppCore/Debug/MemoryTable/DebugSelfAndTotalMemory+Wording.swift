import MultishellCore

/// What a line under an expanded row says in its Self and Total cells, and
/// where the table is too narrow for columns.
extension DebugSelfAndTotalMemory {
  public var selfMemoryText: String { DebugValueText.memory(selfMemory) }

  public var totalMemoryText: String { DebugValueText.memory(totalMemory) }

  /// Its own memory, and the whole beside it where anything sits under it.
  public var memorySummary: String {
    guard totalMemory != selfMemory else { return totalMemoryText }
    return t("debug.self-of-total", selfMemoryText, totalMemoryText)
  }
}
