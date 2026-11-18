import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugMemoryTableTests {
  private let location = DebugLocation(projectName: "acme", worktreeName: "main")

  private func tab(
    _ title: String,
    _ processes: [ProcessUsage],
    terminalMemory: UInt64? = nil,
  ) -> DebugTabMemory {
    DebugTabMemory(
      id: UUID(),
      title: title,
      location: location,
      terminalMemory: terminalMemory,
      processes: processes,
    )
  }

  @Test func theAppComesFirstThenTheTabsThenOtherProcessesAndTheTotalLast() {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [
        tab("Claude", [.sample(pid: 10, footprint: 800)]), tab("Shell", [.sample(pid: 20)]),
      ],
      unattributedProcesses: [.sample(pid: 30, footprint: 50)],
    )

    #expect(
      table.rows.map(\.title) == [
        "Multishell", "Claude", "Shell", "Other processes", "Total, app and child processes",
      ]
    )
    #expect(table.rows.map(\.totalMemory) == [400, 800, 100, 50, 1_350])
    #expect(table.rows.map(\.barFraction) == [0.5, 1, 0.125, 0.0625, 0])
  }

  @Test func otherProcessesAreLeftOutWhereEveryChildIsATabs() {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20)])],
      unattributedProcesses: [],
    )
    #expect(!table.rows.contains { $0.source == .unattributed })
  }

  @Test func aTabTheEngineCouldNotPlaceShowsNoMemoryRatherThanZero() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [])],
      unattributedProcesses: [],
    )
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.processCount == nil)
    #expect(row.totalMemory == nil)
    #expect(row.totalMemoryText == "–")
    #expect(row.disclosure(isExpanded: true) == .notExpandable)
  }

  @Test func aRowWithProcessesOpensToListThem() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20), .sample(pid: 21, parentPID: 20)])],
      unattributedProcesses: [],
    )
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.processRows.map(\.depth) == [0, 1])
    #expect(row.disclosure(isExpanded: false) == .collapsed)
    #expect(row.disclosure(isExpanded: true) == .expanded)
  }

  @Test func theAppRowOpensOnlyWhereItHasPartsToList() {
    let bare = DebugMemoryTable(appMemory: 400, tabs: [], unattributedProcesses: [])
    let measured = DebugMemoryTable(
      appMemory: 400,
      tabs: [],
      unattributedProcesses: [],
      appParts: ProcessMemoryParts(gpuMemory: 100, heapMemory: 100, heapInUse: 50),
    )

    #expect(bare.rows.first?.disclosure(isExpanded: true) == .notExpandable)
    #expect(measured.rows.first?.disclosure(isExpanded: true) == .expanded)
  }

  @Test func aTabsTerminalCountsInTheTabsRowRatherThanTheApps() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20)], terminalMemory: 150)],
      unattributedProcesses: [],
    )
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(table.rows.first?.totalMemory == 250)
    #expect(row.selfMemory == 250)
    #expect(row.totalMemory == 250)
    #expect(table.totalMemory == 500)
  }

  @Test func anExpandedTabListsItsTerminalWithItsShellsIndentedUnderIt() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [
        tab("Shell", [.sample(pid: 20), .sample(pid: 21, parentPID: 20)], terminalMemory: 150)
      ],
      unattributedProcesses: [],
    )
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.terminalRow == DebugTerminalRow(selfMemory: 150, totalMemory: 350))
    #expect(row.processRows.map(\.depth) == [0, 1])
    #expect(row.processRows.map(row.indentLevel(of:)) == [1, 2])
  }

  @Test func aTabWithNoTerminalReadingListsItsShellsAtTheTop() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20)])],
      unattributedProcesses: [],
    )
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.terminalRow == nil)
    #expect(row.processRows.map(row.indentLevel(of:)) == [0])
    #expect(table.rows.first?.totalMemory == 400)
  }

  @Test func theAppsPartsAddUpToItsRowWithTheFileTabsUnderTheHeapInUse() throws {
    let table = DebugMemoryTable(
      appMemory: 500,
      tabs: [tab("Shell", [.sample(pid: 20)], terminalMemory: 100)],
      unattributedProcesses: [],
      fileTabs: DebugFileTabMemory(tabCount: 2, contentMemory: 30),
      appParts: ProcessMemoryParts(gpuMemory: 200, heapMemory: 150, heapInUse: 100),
    )
    let appRow = try #require(table.rows.first)

    #expect(table.rows.map(\.source) == [.app, .tab(table.tabs[0].id), .total])
    #expect(appRow.totalMemory == 400)
    #expect(
      appRow.appPartRows.map(\.title) == [
        "GPU", "Heap in use", "File tabs, 2 open, estimated", "Freed heap malloc keeps",
        "Libraries, stacks and other",
      ]
    )
    #expect(appRow.appPartRows.map(\.selfMemory) == [200, 70, 30, 50, 50])
    #expect(appRow.appPartRows.map(\.totalMemory) == [200, 100, 30, 50, 50])
    #expect(appRow.appPartRows.map(\.indentLevel) == [0, 0, 1, 0, 0])
    #expect(
      appRow.appPartRows.filter { $0.indentLevel == 0 }.reduce(0) { $0 + $1.totalMemory } == 400
    )
  }

  @Test func theAppsPartsNeverPassItsRowWhereTheyReadMoreThanItHolds() throws {
    let table = DebugMemoryTable(
      appMemory: 300,
      tabs: [],
      unattributedProcesses: [],
      fileTabs: DebugFileTabMemory(tabCount: 1, contentMemory: 500),
      appParts: ProcessMemoryParts(gpuMemory: 250, heapMemory: 200, heapInUse: 300),
    )
    let appRow = try #require(table.rows.first)

    #expect(appRow.appPartRows.map(\.selfMemory) == [250, 0, 50, 0, 0])
  }

  @Test func theFileTabsStillShowUnderTheAppWhereItsPartsCouldNotBeRead() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [],
      unattributedProcesses: [],
      fileTabs: DebugFileTabMemory(tabCount: 2, contentMemory: 150),
    )
    let appRow = try #require(table.rows.first)

    #expect(table.rows.map(\.source) == [.app, .total])
    #expect(appRow.totalMemory == 400)
    #expect(appRow.appPartRows.map(\.part) == [.fileTabs])
    #expect(appRow.appPartRows.map(\.indentLevel) == [0])
  }

  @Test func theAppRowStopsAtZeroWhereItsTerminalsReadMoreThanItsFootprint() {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [.sample(pid: 20)], terminalMemory: 500)],
      unattributedProcesses: [],
    )
    #expect(table.rows.first?.totalMemory == 0)
    #expect(table.totalMemory == 500)
  }

  @Test func aTabTheEngineCouldNotPlaceShowsItsTerminalAloneSoTheRowsStillAddUp() throws {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [tab("Shell", [], terminalMemory: 150)],
      unattributedProcesses: [],
    )
    let row = try #require(table.rows.first { $0.title == "Shell" })

    #expect(row.processCount == nil)
    #expect(row.selfMemory == 150)
    #expect(row.totalMemory == 150)
    #expect(table.rows.first?.totalMemory == 250)
    #expect(table.totalMemory == 400)
    #expect(row.terminalRow == DebugTerminalRow(selfMemory: 150, totalMemory: 150))
    #expect(row.disclosure(isExpanded: false) == .collapsed)
  }
}
