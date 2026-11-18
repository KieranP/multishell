import MultishellCore
import MultishellProcess

extension AccessibilityText {
  /// The sidebar's quick stats, read as the one button they are.
  public static func debugQuickStats(_ stats: DebugQuickStats) -> String {
    var parts = [t("spoken.debug-info")]
    if let totalCPUPercent = stats.totalCPUPercent {
      parts.append(t("spoken.cpu", DebugValueText.percent(totalCPUPercent)))
    }
    if let memory = stats.totalMemory {
      parts.append(t("spoken.memory", DebugValueText.memory(memory)))
    }
    if stats.diskBytesPerSecond != nil {
      parts.append(t("spoken.disk-per-second", stats.diskText))
    }
    return parts.joined(separator: ", ")
  }

  /// A Memory Breakdown row, read as one button where it opens to list its parts or processes.
  public static func debugMemoryRow(
    _ row: DebugMemoryRow,
    disclosure: DebugRowDisclosure,
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
    case .collapsed, .expanded: parts.append(Self.disclosure(isExpanded: disclosure == .expanded))
    }
    return parts.joined(separator: ", ")
  }

  /// The terminals under an expanded tab, read as the process rows are.
  public static func debugTerminalRow(_ row: DebugTerminalRow) -> String {
    debugNestedRow(row.title, row)
  }

  /// A debug table's column title, a button that sorts by it, saying which
  /// way where the table is sorted by it.
  public static func debugColumnHeader<Column: DebugSortableColumn>(
    _ title: String,
    column: Column,
    sort: DebugTableSort<Column>,
  ) -> String {
    guard column == sort.column else { return title }
    let direction = sort.isAscending ? t("spoken.sorted-ascending") : t("spoken.sorted-descending")
    return t("spoken.named", title, direction)
  }

  /// A row of CPU Breakdown, its numbers named, and whether it opens where it does.
  public static func debugThreadRow(
    _ row: some DebugThreadFigures,
    disclosure: DebugRowDisclosure,
  ) -> String {
    var parts = [
      row.title, t("count.threads", row.threadCount),
      t("spoken.mean-cpu", row.meanPercentText), t("spoken.cpu-time", row.cpuTimeText),
    ]
    if disclosure.isExpandable {
      parts.append(Self.disclosure(isExpanded: disclosure == .expanded))
    }
    return parts.joined(separator: ", ")
  }

  /// A row of App Activity, its total first, as the table sorts by it.
  public static func debugAppActivityRow(_ row: DebugAppActivityRow) -> String {
    ([row.title, t("spoken.total-time", row.totalDurationText)] + row.stackedCaptions)
      .joined(separator: ", ")
  }

  /// A part of the app's footprint under its expanded row, said to be part
  /// of the row above where the arrow shows it is.
  public static func debugAppPartRow(_ row: DebugAppPartRow) -> String {
    guard row.indentLevel > 0 else { return debugNestedRow(row.title, row) }
    return debugNestedRow(t("spoken.named", row.title, t("spoken.part-of-row-above")), row)
  }

  /// A process under an expanded row, its depth said where the arrow shows
  /// it: under the process that started it, or the terminal it runs in.
  public static func debugProcessRow(
    _ process: DebugProcessRow,
    under row: DebugMemoryRow,
  ) -> String {
    var parts = [process.process.name]
    if process.depth > 0 {
      parts.append(t("spoken.tree-depth", process.depth))
    } else if row.terminalRow != nil {
      parts.append(t("spoken.runs-in-terminal"))
    }
    parts.append(t("spoken.self-memory", process.selfMemoryText))
    parts.append(t("spoken.total-memory", process.totalMemoryText))
    return parts.joined(separator: ", ")
  }

  private static func debugNestedRow(
    _ title: String,
    _ memory: any DebugSelfAndTotalMemory,
  ) -> String {
    [
      title, t("spoken.self-memory", memory.selfMemoryText),
      t("spoken.total-memory", memory.totalMemoryText),
    ].joined(separator: ", ")
  }
}
