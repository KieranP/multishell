import Testing

@testable import MultishellAppCore

@Suite
struct DebugMemoryRecordTests {
  @Test func theFileTabsTextIsPrintedSoTheFiguresStillAddUp() {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [],
      unattributedProcesses: [],
      fileTabs: DebugFileTabMemory(tabCount: 2, textMemory: 150),
    )

    let record = DebugMemoryRecord(table)

    #expect(record.appMemoryOutsideTabs == 250)
    #expect(record.fileTabs == DebugMemoryRecord.FileTabsRecord(count: 2, textMemory: 150))
  }
}
