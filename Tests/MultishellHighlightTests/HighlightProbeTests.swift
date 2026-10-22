import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightProbeTests {
  @Test func aWordMissingFromTheTextFailsTheTestAskingForIt() {
    withKnownIssue {
      _ = HighlightProbe.role(of: "absent", in: "<p>x</p>", language: .html)
    }
  }
}
