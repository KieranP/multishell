import Testing

@testable import MultishellAppCore

@Suite
struct DropHalfTests {
  @Test func thePointerBeforeTheMidpointIsInTheLeadingHalf() {
    #expect(DropHalf(at: 0, along: 100) == .leading)
    #expect(DropHalf(at: 49.9, along: 100) == .leading)
  }

  @Test func theMidpointItselfIsTheTrailingHalf() {
    #expect(DropHalf(at: 50, along: 100) == .trailing)
    #expect(DropHalf(at: 100, along: 100) == .trailing)
  }

  @Test func aTargetNotYetMeasuredReadsAsTheLeadingHalf() {
    #expect(DropHalf(at: 30, along: 0) == .leading)
  }
}
