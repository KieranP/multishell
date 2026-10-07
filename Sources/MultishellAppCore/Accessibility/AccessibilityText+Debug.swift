import MultishellCore

extension AccessibilityText {
  /// The sidebar's quick stats, read as the one button they are.
  public static func debugQuickStats(_ stats: DebugQuickStats) -> String {
    var parts = [t("spoken.debug-info")]
    if let framesPerSecond = stats.framesPerSecond {
      parts.append(t("count.frames-per-second", framesPerSecond))
    }
    if let totalCPUPercent = stats.totalCPUPercent {
      parts.append(t("spoken.cpu", DebugValueText.percent(totalCPUPercent)))
    }
    if let memory = stats.totalMemory {
      parts.append(t("spoken.memory", DebugValueText.memory(memory)))
    }
    return parts.joined(separator: ", ")
  }

  /// A Memory by tab row, read as one button where it opens to list processes.
  public static func debugMemoryLine(
    _ line: DebugMemoryLine, disclosure: DebugLineDisclosure
  ) -> String {
    var parts = [line.title]
    if !line.subtitle.isEmpty { parts.append(line.subtitle) }
    if let processCount = line.processCount { parts.append(t("count.processes", processCount)) }
    if let selfMemory = line.selfMemory {
      parts.append(t("spoken.self-memory", DebugValueText.memory(selfMemory)))
    }
    parts.append(t("spoken.total-memory", line.totalMemoryText))
    switch disclosure {
    case .notExpandable: break
    case .collapsed: parts.append(t("spoken.collapsed"))
    case .expanded: parts.append(t("spoken.expanded"))
    }
    return parts.joined(separator: ", ")
  }

  /// A process under an expanded row, its depth said where the arrow shows it.
  public static func debugProcessLine(_ line: DebugProcessLine) -> String {
    var parts = [line.process.name]
    if line.depth > 0 { parts.append(t("spoken.tree-depth", line.depth)) }
    parts.append(t("spoken.self-memory", DebugValueText.memory(line.selfMemory)))
    parts.append(t("spoken.total-memory", DebugValueText.memory(line.totalMemory)))
    return parts.joined(separator: ", ")
  }
}
