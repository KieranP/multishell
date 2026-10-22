import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct NSRangeIntegerRangeTests {
  @Test func anNSRangeBecomesTheIntegerRangeOverTheSameUnits() {
    #expect(NSRange(location: 3, length: 4).integerRange == 3..<7)
    #expect(NSRange(location: 5, length: 0).integerRange == 5..<5)
  }
}
