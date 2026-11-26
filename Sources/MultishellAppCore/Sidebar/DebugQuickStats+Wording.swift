import MultishellCore

/// What the sidebar's three cells say, none before the first sample.
extension DebugQuickStats {
  public var totalCPUText: String {
    totalCPUPercent.map(DebugValueText.percent) ?? DebugValueText.noValue
  }

  public var totalMemoryText: String {
    totalMemory.map(DebugValueText.compactMemory) ?? DebugValueText.noValue
  }

  /// Bytes alone: the cell's title carries the "/s", which the narrowest
  /// sidebar has no room for beside the widest figures.
  public var diskText: String {
    diskBytesPerSecond.map(DebugValueText.compactBytes) ?? DebugValueText.noValue
  }
}
