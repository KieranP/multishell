import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperDebugServicesTests {
  @Test func aStandInThatIsNotUTF8IsAUsageErrorThatAsksNothing() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let file = Scratch.path("stand-in-latin1.json")
    defer { Scratch.remove(file) }
    try Data(#"{"pullRequests": [{"title": "Caf"#.utf8 + [0xE9] + #""}]}"#.utf8).write(to: file)

    let output = try await HelperBinary.run(
      ["debug", "services", "stand-in", file.path],
      environment: app.environment,
    )

    #expect(output.status == 2, "\(output.standardError)")
    #expect(app.requests.received.isEmpty)
  }

  @Test func aStandInIsReadFromTheFileAndSentAsItsText() async throws {
    let app = try ControlListener(reply: .done)
    defer { app.stop() }
    let file = Scratch.path("stand-in.json")
    defer { Scratch.remove(file) }
    let json = #"{"ciRuns": []}"#
    try json.write(to: file, atomically: true, encoding: .utf8)

    let output = try await HelperBinary.run(
      ["debug", "services", "stand-in", file.path],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(app.requests.received == [.standInServices(json: json)])
  }
}
