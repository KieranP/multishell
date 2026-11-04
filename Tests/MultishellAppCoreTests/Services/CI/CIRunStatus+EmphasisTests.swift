import Testing

@testable import MultishellAppCore
@testable import MultishellServices

@Suite
struct CIRunStatusEmphasisTests {
  @Test func onlyAFailureDrawsTheEye() {
    #expect(CIRunStatus.failed.drawsAttention)
    #expect(!CIRunStatus.passed.drawsAttention)
    #expect(!CIRunStatus.running.drawsAttention)
  }
}
