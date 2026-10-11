import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperPaneFindingTests {
  @Test func aFindWaitsForTheEngineToCountAndPrintsTheBar() async throws {
    let app = try ControlListener.answeringInTurn { look in
      let total = look < 2 ? "" : #","total":3"#
      return .output(#"{"id":"P","find":{"text":"error"\#(total)}}"#)
    }
    defer { app.stop() }
    let pane = UUID()

    let output = try await HelperBinary.run(
      ["panes", "find", pane.uuidString, "error"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    let fields = printed as? [String: Any]
    #expect(fields?["pane"] as? String == pane.uuidString)
    #expect((fields?["find"] as? [String: Any])?["total"] as? Int == 3)
    #expect(app.requests.received.first == .findInPane(id: pane, action: .search("error")))
  }

  @Test func closingPrintsTheBarAsGone() async throws {
    let app = try ControlListener(reply: .output(#"{"id":"P"}"#))
    defer { app.stop() }
    let pane = UUID()

    let output = try await HelperBinary.run(
      ["panes", "find", pane.uuidString, "--close"],
      environment: app.environment,
    )

    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    #expect((printed as? [String: Any])?["find"] is NSNull, "\(output.standardOutput)")
    #expect(app.requests.received == [.findInPane(id: pane, action: .close)])
  }

  @Test func aCountIsPrintedOnceTheEngineHasSettledNotItsInterimZero() async throws {
    let app = try ControlListener.answeringInTurn { look in
      let total = look < 3 ? 0 : 5
      return .output(#"{"id":"P","find":{"text":"x","total":\#(total)}}"#)
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "find", UUID().uuidString, "x"],
      environment: app.environment,
    )

    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    #expect(((printed as? [String: Any])?["find"] as? [String: Any])?["total"] as? Int == 5)
  }

  @Test func aStepWaitsForTheNewSelection() async throws {
    let app = try ControlListener.answeringInTurn { look in
      let selected = look < 2 ? "" : #","selected":1"#
      return .output(#"{"id":"P","find":{"text":"x","total":5\#(selected)}}"#)
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "find", UUID().uuidString, "--next"],
      environment: app.environment,
    )

    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    #expect(((printed as? [String: Any])?["find"] as? [String: Any])?["selected"] as? Int == 1)
  }

  @Test func aLookCutShortAtTheDeadlinePrintsTheBarAsItStood() async throws {
    let app = try ControlListener { _ in
      Thread.sleep(forTimeInterval: 0.35)
      return .output(#"{"id":"P","find":{"text":"x"}}"#)
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "find", UUID().uuidString, "x"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    let printed = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    #expect(((printed as? [String: Any])?["find"] as? [String: Any])?["text"] as? String == "x")
  }

  @Test func anEmptyTextIsAUsageError() async throws {
    #expect(try await HelperBinary.run(["panes", "find", UUID().uuidString, ""]).status == 2)
  }

  @Test func aFindWithoutExactlyOneActionIsAUsageError() async throws {
    let id = UUID().uuidString

    #expect(try await HelperBinary.run(["panes", "find", id]).status == 2)
    #expect(try await HelperBinary.run(["panes", "find", id, "x", "--next"]).status == 2)
  }
}
