import Testing

@testable import MultishellAppCore

@Suite
struct DebugMemoryColumnTests {
  @Test func namesStartAToZAndFiguresLargestFirst() {
    #expect(DebugMemoryColumn.name.sortsAscendingFirst)
    #expect(DebugMemoryColumn.worktree.sortsAscendingFirst)
    for column in [DebugMemoryColumn.processCount, .selfMemory, .totalMemory] {
      #expect(!column.sortsAscendingFirst, "\(column)")
    }
  }
}
