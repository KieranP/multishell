import Testing

@testable import MultishellAppCore

@Suite
struct RandomAccessCollectionPartitioningIndexTests {
  @Test func findsTheFirstElementPastThePartitionOrTheEndWhereNoneIs() {
    let values = [2, 6, 10]

    #expect(values.partitioningIndex { $0 >= 0 } == 0)
    #expect(values.partitioningIndex { $0 >= 6 } == 1)
    #expect(values.partitioningIndex { $0 >= 7 } == 2)
    #expect(values.partitioningIndex { $0 >= 11 } == 3)
    #expect([Int]().partitioningIndex { $0 >= 1 } == 0)
  }
}
