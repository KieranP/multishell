import Testing

@testable import MultishellAppCore

@Suite
struct DebugAppActivityColumnTests {
  @Test func theActivityStartsAToZAndFiguresLargestFirst() {
    #expect(DebugAppActivityColumn.activity.sortsAscendingFirst)
    for column in [
      DebugAppActivityColumn.bytesWritten, .count, .meanDuration, .slowestDuration, .totalDuration,
    ] {
      #expect(!column.sortsAscendingFirst, "\(column)")
    }
  }
}
