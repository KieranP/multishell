import Foundation
import Testing

@testable import MultishellProcess

@Suite(.serialized)
struct HelperArgumentsTests {
  @Test func aShareBelowZeroIsAUsageErrorSayingSharesAreAboveZero() async throws {
    let output = try await HelperBinary.run(["tabs", "resize", UUID().uuidString, "1", "-1"])

    #expect(output.status == 2)
    #expect(
      output.standardError.contains("shares are numbers above zero"),
      "\(output.standardError)",
    )
  }
}
