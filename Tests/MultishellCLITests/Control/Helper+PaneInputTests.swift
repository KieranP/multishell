import Foundation
import Testing

@testable import MultishellProcess

@Suite
struct HelperPaneInputTests {
  @Test func aKeyItDoesNotKnowOrNoKeyAtAllIsAUsageError() async throws {
    let id = UUID().uuidString

    #expect(try await HelperBinary.run(["panes", "key", id, "hyper-x"]).status == 2)
    #expect(try await HelperBinary.run(["panes", "key", id]).status == 2)
  }
}
