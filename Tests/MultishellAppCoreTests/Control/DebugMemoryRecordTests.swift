import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugMemoryRecordTests {
  @Test func theAppsPartsArePrintedEachAtItsOwnShare() {
    let table = DebugMemoryTable(
      appMemory: 400,
      tabs: [],
      unattributedProcesses: [],
      fileTabs: DebugFileTabMemory(tabCount: 2, contentMemory: 30),
      appParts: ProcessMemoryParts(gpuMemory: 200, heapMemory: 150, heapInUse: 100),
    )

    let record = DebugMemoryRecord(table)

    #expect(record.appMemoryOutsideTerminals == 400)
    #expect(record.fileTabs == DebugMemoryRecord.FileTabsRecord(count: 2, contentMemory: 30))
    #expect(
      record.appParts.map(\.part) == [
        "gpu", "heapInUse", "fileTabs", "freedHeap", "librariesAndOther",
      ]
    )
    #expect(record.appParts.map(\.memory) == [200, 70, 30, 50, 50])
  }
}
