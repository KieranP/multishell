import MultishellCore

/// What the sidebar's three cells say, none before the first sample.
extension DebugQuickStats {
  public var framesPerSecondText: String {
    framesPerSecond.map(String.init) ?? DebugValueText.noValue
  }

  public var totalCPUText: String {
    totalCPUPercent.map(DebugValueText.percent) ?? DebugValueText.noValue
  }

  public var totalMemoryText: String {
    totalMemory.map(DebugValueText.memory) ?? DebugValueText.noValue
  }
}
