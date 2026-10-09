import MultishellCore
import MultishellProcess

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
  public static func debugMemoryRow(
    _ row: DebugMemoryRow, disclosure: DebugRowDisclosure
  ) -> String {
    var parts = [row.title]
    if !row.subtitle.isEmpty { parts.append(row.subtitle) }
    if let processCount = row.processCount { parts.append(t("count.processes", processCount)) }
    if let selfMemory = row.selfMemory {
      parts.append(t("spoken.self-memory", DebugValueText.memory(selfMemory)))
    }
    parts.append(t("spoken.total-memory", row.totalMemoryText))
    switch disclosure {
    case .notExpandable: break
    case .collapsed: parts.append(t("spoken.collapsed"))
    case .expanded: parts.append(t("spoken.expanded"))
    }
    return parts.joined(separator: ", ")
  }

  /// The terminals under an expanded tab, read as the process rows are.
  public static func debugTerminalRow(_ row: DebugTerminalRow) -> String {
    [
      row.title, t("spoken.self-memory", row.selfMemoryText),
      t("spoken.total-memory", row.totalMemoryText),
    ].joined(separator: ", ")
  }

  /// A process under an expanded row, its depth said where the arrow shows
  /// it: under the process that started it, or the terminal it runs in.
  public static func debugProcessRow(
    _ process: DebugProcessRow, under row: DebugMemoryRow
  ) -> String {
    var parts = [process.process.name]
    if process.depth > 0 {
      parts.append(t("spoken.tree-depth", process.depth))
    } else if row.terminalRow != nil {
      parts.append(t("spoken.runs-in-terminal"))
    }
    parts.append(t("spoken.self-memory", DebugValueText.memory(process.selfMemory)))
    parts.append(t("spoken.total-memory", DebugValueText.memory(process.totalMemory)))
    return parts.joined(separator: ", ")
  }
}
