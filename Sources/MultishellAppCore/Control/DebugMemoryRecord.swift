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
  let appMemoryOutsideTerminals: UInt64
  let totalMemory: UInt64
  let tabs: [TabRecord]
  let otherProcesses: [ProcessRecord]

  init(_ table: DebugMemoryTable) {
    appMemory = table.appMemory
    appMemoryOutsideTerminals = table.appMemoryOutsideTerminals
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
