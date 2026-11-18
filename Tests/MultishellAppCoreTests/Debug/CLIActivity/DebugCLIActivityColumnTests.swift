import Testing

@testable import MultishellAppCore

@Suite
struct DebugCLIActivityColumnTests {
  @Test func textStartsAToZAndFiguresLargestFirst() {
    #expect(DebugCLIActivityColumn.command.sortsAscendingFirst)
    #expect(DebugCLIActivityColumn.slowestLocation.sortsAscendingFirst)
    for column in [
      DebugCLIActivityColumn.runs, .totalDuration, .meanDuration, .slowestDuration,
      .meanPeakMemory, .peakMemory,
    ] {
      #expect(!column.sortsAscendingFirst, "\(column)")
    }
  }

  @Test func theCaptionNamesTheSortedColumn() {
    #expect(DebugCLIActivityColumn.defaultSort.title == "total time")
    #expect(DebugCLIActivityColumn.slowestLocation.sortTitle == "where the slowest ran")
  }
}
