import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperFileTabReadWaitTests {
  @Test func aStepOrFindRefusedWhileItsRowsAreReadIsAskedAgain() async throws {
    let id = UUID()
    for line in [
      ["tabs", "step", id.uuidString, "--next"],
      ["tabs", "find", id.uuidString, "foo"],
    ] {
      let app = try ControlListener.answeringInTurn { turn in
        turn == 0 ? .refused(.fileTabNotRead(id: id)) : .output("{}")
      }
      defer { app.stop() }

      let output = try await HelperBinary.run(line, environment: app.environment)

      #expect(output.succeeded, "\(line): \(output.standardError)")
      #expect(app.requests.received.count == 2, "\(line): \(app.requests.received)")
    }
  }
}
