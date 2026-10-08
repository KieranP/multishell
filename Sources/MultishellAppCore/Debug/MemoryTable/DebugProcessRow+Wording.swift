import MultishellCore

/// What an expanded process says in its Self and Total cells, and where the
/// table is too narrow for columns.
extension DebugProcessRow {
  public var selfMemoryText: String { DebugValueText.memory(selfMemory) }

  public var totalMemoryText: String { DebugValueText.memory(totalMemory) }

  /// Its own memory, and the whole beside it where it started anything.
  public var memorySummary: String {
    guard totalMemory != selfMemory else { return totalMemoryText }
    return t("debug.self-of-total", selfMemoryText, totalMemoryText)
  }
}
