import Testing

@testable import MultishellAppCore

@Suite
struct DebugThreadColumnTests {
  @Test func theThreadNameStartsAToZAndFiguresLargestFirst() {
    #expect(DebugThreadColumn.thread.sortsAscendingFirst)
    for column in [DebugThreadColumn.cpuTime, .meanPercent, .threadCount] {
      #expect(!column.sortsAscendingFirst, "\(column)")
    }
  }
}
