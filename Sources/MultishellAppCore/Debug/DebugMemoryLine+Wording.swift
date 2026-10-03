import MultishellCore

/// What a Memory by tab row says in its cells, and under its title where the
/// table is too narrow for columns.
extension DebugMemoryLine {
  /// The total row leaves its count and Self empty; an unplaced tab says so.
  public var processCountText: String {
    processCount.map(String.init) ?? (isTotal ? "" : DebugValueText.noValue)
  }

  public var selfMemoryText: String {
    selfMemory.map(DebugValueText.memory) ?? (isTotal ? "" : DebugValueText.noValue)
  }

  public var totalMemoryText: String {
    totalMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }

  /// The subtitle, with the count and Self beside it where there are any.
  public var stackedCaption: String? {
    guard let processCount, let selfMemory else { return subtitle.isEmpty ? nil : subtitle }
    return t(
      "debug.subtitle-count-and-self", subtitle, t("count.processes", processCount),
      DebugValueText.memory(selfMemory))
  }
}
