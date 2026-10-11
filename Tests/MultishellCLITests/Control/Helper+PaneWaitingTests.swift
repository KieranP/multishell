import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperPaneWaitingTests {
  private static func pane(_ state: String) -> ControlReply {
    .output(#"{"id":"P","state":"\#(state)"}"#)
  }

  @Test func aWaitForAStateReturnsOnceThePaneShowsItAndPrintsThePane() async throws {
    let app = try ControlListener.answeringInTurn { look in
      look < 2 ? Self.pane("running") : Self.pane("done")
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "wait", UUID().uuidString, "--state", "done"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(output.standardOutput.contains(#""state":"done""#))
    #expect(app.requests.received.count == 3)
  }

  @Test func aWaitForNoStateReturnsOnceTheDotHasGone() async throws {
    let app = try ControlListener(reply: .output(#"{"id":"P"}"#))
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "wait", UUID().uuidString, "--state", "none"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
  }

  @Test func aWaitForIdleReturnsOnceTheDotHasGoneAsTheAppKeepsNoIdleState() async throws {
    let app = try ControlListener(reply: .output(#"{"id":"P"}"#))
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "wait", UUID().uuidString, "--state", "idle", "--timeout", "2"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
  }

  @Test func aWaitForTextPrintsTheNewestLineThatMatchesAsJSON() async throws {
    let app = try ControlListener(reply: .output("ready on :3000\nbuild ok\nready on :3001\n"))
    defer { app.stop() }

    let pane = UUID()

    let output = try await HelperBinary.run(
      ["panes", "wait", pane.uuidString, "--text", "ready on :[0-9]+"],
      environment: app.environment,
    )

    let found = try JSONSerialization.jsonObject(with: Data(output.standardOutput.utf8))
    #expect(
      (found as? [String: String]) == ["pane": pane.uuidString, "line": "ready on :3001"],
      "\(output.standardOutput)\(output.standardError)",
    )
  }

  @Test func aWaitInTheScrollbackReadsItOnceThenWatchesTheScreen() async throws {
    let app = try ControlListener.answeringInTurn { look in
      .output(look < 2 ? "building\n" : "ready\n")
    }
    defer { app.stop() }
    let pane = UUID()

    let output = try await HelperBinary.run(
      ["panes", "wait", pane.uuidString, "--text", "ready", "--scrollback"],
      environment: app.environment,
    )

    #expect(output.succeeded, "\(output.standardError)")
    #expect(
      app.requests.received == [
        .readPane(id: pane, includingScrollback: true),
        .readPane(id: pane, includingScrollback: false),
        .readPane(id: pane, includingScrollback: false),
      ]
    )
  }

  @Test func aWaitThatRunsOutOfTimeExitsOneAndSaysHowLongItWaited() async throws {
    let app = try ControlListener(reply: Self.pane("running"))
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "wait", UUID().uuidString, "--state", "done", "--timeout", "0.5"],
      environment: app.environment,
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("within 0.5 seconds"), "\(output.standardError)")
  }

  @Test func aWaitForAStateThatDoesNotExistOrForNothingIsAUsageError() async throws {
    let id = UUID().uuidString

    #expect(try await HelperBinary.run(["panes", "wait", id, "--state", "asleep"]).status == 2)
    #expect(try await HelperBinary.run(["panes", "wait", id]).status == 2)
    #expect(try await HelperBinary.run(["panes", "wait", id, "--text", "("]).status == 2)
  }

  @Test func aLookCutShortByTheDeadlineIsTakenForNotYet() async throws {
    let app = try ControlListener { _ in
      Thread.sleep(forTimeInterval: 0.2)
      return Self.pane("running")
    }
    defer { app.stop() }

    let output = try await HelperBinary.run(
      ["panes", "wait", UUID().uuidString, "--state", "done", "--timeout", "0.5"],
      environment: app.environment,
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("within 0.5 seconds"), "\(output.standardError)")
  }

  @Test func aTimeoutPastADayOrAFlagTheWaitWouldIgnoreIsAUsageError() async throws {
    let id = UUID().uuidString

    #expect(
      try await HelperBinary.run(["panes", "wait", id, "--state", "done", "--timeout", "1e300"])
        .status == 2
    )
    #expect(
      try await HelperBinary.run(["panes", "wait", id, "--state", "done", "--scrollback"])
        .status == 2
    )
  }
}
