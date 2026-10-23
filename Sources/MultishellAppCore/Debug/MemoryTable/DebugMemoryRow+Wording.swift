import MultishellCore

/// What a Memory by tab row says in its cells, and under its title where the
/// table is too narrow for columns.
extension DebugMemoryRow {
  /// The total row leaves its count and Self empty, and the file tabs, which run no
  /// process, their count; an unplaced tab shows the dash.
  public var processCountText: String {
    processCount.map(String.init)
      ?? (isTotal || source == .fileTabs ? "" : DebugValueText.noValue)
  }

  public var selfMemoryText: String {
    selfMemory.map(DebugValueText.memory) ?? (isTotal ? "" : DebugValueText.noValue)
  }

  public var totalMemoryText: String {
    totalMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  /// The subtitle, with the count and Self beside it where there are any.
  public var stackedCaptions: [String] {
    guard let processCount, let selfMemory else { return subtitle.isEmpty ? [] : [subtitle] }
    let count = t("count.processes", processCount)
    let memory = DebugValueText.memory(selfMemory)
    return [
      subtitle.isEmpty
        ? t("debug.count-and-self", count, memory)
        : t("debug.subtitle-count-and-self", subtitle, count, memory)
    ]
  }
}
