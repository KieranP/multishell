import Testing

@testable import MultishellProcess

@Suite
struct DurationSecondsTests {
  @Test func aDurationReadsAsSecondsWithItsFractionKept() {
    #expect(Duration.milliseconds(1_500).inSeconds == 1.5)
    #expect(Duration.nanoseconds(250).inSeconds == 250e-9)
    #expect(Duration.zero.inSeconds == 0)
  }
}
