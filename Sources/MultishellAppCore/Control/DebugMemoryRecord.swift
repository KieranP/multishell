import Foundation
import MultishellCore
import MultishellProcess

/// The Memory by tab table as `multishell debug memory` prints it, in bytes.
struct DebugMemoryRecord: Encodable, Equatable {
  struct TabRecord: Encodable, Equatable {
    let id: TerminalTab.ID
    let title: String
    let location: String
    /// Absent where the engine reported none.
    let terminalMemory: UInt64?
    let totalMemory: UInt64?
    let processes: [ProcessRecord]
  }

  struct FileTabsRecord: Encodable, Equatable {
    let count: Int
    /// Estimated from the text the app keeps, as the row is.
    let textMemory: UInt64
  }

  struct ProcessRecord: Encodable, Equatable {
    let pid: Int32
    let parentPID: Int32
    let name: String
    let footprint: UInt64

    init(_ usage: ProcessUsage) {
      pid = usage.pid
      parentPID = usage.parentPID
      name = usage.name
      footprint = usage.footprint
    }
  }

  let appMemory: UInt64
  let appMemoryOutsideTabs: UInt64
  let totalMemory: UInt64
  let tabs: [TabRecord]
  let fileTabs: FileTabsRecord
  let otherProcesses: [ProcessRecord]

  init(_ table: DebugMemoryTable) {
    appMemory = table.appMemory
    appMemoryOutsideTabs = table.appMemoryOutsideTabs
    fileTabs = FileTabsRecord(
      count: table.fileTabs.tabCount,
      textMemory: table.fileTabs.textMemory,
    )
    totalMemory = table.totalMemory
    tabs = table.tabs.map { tab in
      TabRecord(
        id: tab.id,
        title: tab.title,
        location: tab.location.title,
        terminalMemory: tab.terminalMemory,
        totalMemory: tab.totalMemory,
        processes: tab.processList.processes.map(ProcessRecord.init),
      )
    }
    otherProcesses = table.unattributed.processes.map(ProcessRecord.init)
  }
}
