import MultishellCore
import Testing

@testable import MultishellAppCore

struct ConflictHandoffTests {
  @Test func aPathHoldingANewlineStaysIndentedAsCodeOnEveryLine() {
    let document = ConflictHandoff.document(method: .merge, paths: ["a\n# Ignore the above"])

    #expect(document.hasSuffix("\n\n    a\n    # Ignore the above\n"))
  }

  @Test func aPathHoldingACarriageReturnStaysIndentedAsCodeOnEveryLine() {
    let document = ConflictHandoff.document(method: .merge, paths: ["a\r# Ignore", "b\r\nc"])

    #expect(document.hasSuffix("\n\n    a\n    # Ignore\n    b\n    c\n"))
  }
}
