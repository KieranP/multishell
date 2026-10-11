import Testing

@testable import MultishellProcess

@Suite
struct HelperWindowCommandsTests {
  @Test func aWindowSizeThatIsNoNumberOfPointsIsAUsageError() async throws {
    for size in [["inf", "600"], ["900", "0"], ["1e300", "600"]] {
      #expect(try await HelperBinary.run(["window", "size"] + size).status == 2, "\(size)")
    }
  }
}
