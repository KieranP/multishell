import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperTabCommandsTests {
  @Test func aTabCommandSendsItsWorktreeAndCommandAndPrintsTheAnswer() async throws {
    let app = try ControlListener(reply: .output(#"{"tab":"T"}"#))
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["tabs", "open", "w-0123abcd", "--", "npm", "run", "--watch"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(output.standardOutput == #"{"tab":"T"}"# + "\n")
    let request = try #require(app.requests.received.first)
    guard case .newTab(let order) = request else {
      Issue.record("asked \(request)")
      return
    }
    #expect(order.worktreeID == "w-0123abcd")
    #expect(order.command == ["npm", "run", "--watch"])
    #expect(order.agentID == nil)
  }
}
