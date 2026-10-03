import MultishellCore

/// What an expanded process says where the table is too narrow for columns.
extension DebugProcessLine {
  /// Its own memory, and the whole beside it where it started anything.
  public var memorySummary: String {
    guard totalMemory != selfMemory else { return DebugValueText.memory(totalMemory) }
    return t(
      "debug.self-of-total", DebugValueText.memory(selfMemory), DebugValueText.memory(totalMemory))
  }
}
