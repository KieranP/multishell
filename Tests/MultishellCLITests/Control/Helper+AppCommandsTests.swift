import Foundation
import TestScratch
import Testing

@testable import MultishellCLI
@testable import MultishellCore
@testable import MultishellProcess

@Suite(.serialized)
struct HelperAppCommandsTests {
  @Test func quittingAnAppThatHasGoneSucceedsAndARefusalIsSaid() async throws {
    let gone = try await HelperBinary.run(
      ["quit"],
      environment: [Helper.controlSocketVariable: "/tmp/ms-nobody.sock"],
    )
    #expect(gone.succeeded, "\(gone.standardError)")

    let app = try ControlListener(reply: .refused(.agentWorking))
    defer { app.stop() }
    let refused = try await HelperBinary.run(["quit"], environment: app.environment)
    #expect(refused.status == 1)
    #expect(
      refused.standardError.contains("--force goes ahead anyway"),
      "\(refused.standardError)",
    )
    #expect(app.requests.received == [.quit(force: false)])
  }

  @Test func quittingAnAppThatAnswersNothingAndStaysUpSaysItMayBeOlder() throws {
    let app = try ControlListener(reply: nil)
    defer { app.stop() }

    let error = #expect(throws: ControlUnanswered.self) {
      try Helper.runQuit([], environment: app.environment, waitingUpTo: .milliseconds(400))
    }

    #expect(error?.description.contains("older than this helper") == true)
  }

  /// The helper copied into a bundle of the test's own, so `open` finds an
  /// app, and a stand-in for `/usr/bin/open` that only records what it was given.
  private func helperInBundle(
    opening exitStatus: Int
  ) throws -> (root: URL, helper: URL, opener: URL) {
    let root = Scratch.path("open")
    let helpers = root.appendingPathComponent("X.app/Contents/Helpers", isDirectory: true)
    try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
    let helper = helpers.appendingPathComponent("multishell")
    try FileManager.default.copyItem(at: try HelperBinary.require(), to: helper)
    let opener = root.appendingPathComponent("opener")
    let record = root.appendingPathComponent("opened").path
    try "#!/bin/sh\nprintf '%s' \"$1\" > '\(record)'\nexit \(exitStatus)\n".write(
      to: opener,
      atomically: true,
      encoding: .utf8,
    )
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: opener.path)
    return (root, helper, opener)
  }

  @Test func openingLaunchesTheBundleTheHelperIsInAndReturnsOnceItAnswers() async throws {
    let app = try ControlListener(reply: .done)
    let (root, helper, opener) = try helperInBundle(opening: 0)
    defer {
      app.stop()
      Scratch.remove(root)
    }

    let output = try await HelperBinary.run(
      ["open"],
      environment: app.environment.merging([Helper.openerVariable: opener.path]) { $1 },
      standIn: helper,
    )

    #expect(output.succeeded, "\(output.standardError)")
    let opened = try String(contentsOf: root.appendingPathComponent("opened"), encoding: .utf8)
    #expect(
      URL(fileURLWithPath: opened).resolvingSymlinksInPath()
        == root.appendingPathComponent("X.app").resolvingSymlinksInPath()
    )
    #expect(app.requests.received == [.info])
  }

  @Test func anOpenThatFailsIsSaidAndAsksNothing() async throws {
    let app = try ControlListener(reply: .done)
    let (root, helper, opener) = try helperInBundle(opening: 1)
    defer {
      app.stop()
      Scratch.remove(root)
    }

    let output = try await HelperBinary.run(
      ["open"],
      environment: app.environment.merging([Helper.openerVariable: opener.path]) { $1 },
      standIn: helper,
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("could not open"), "\(output.standardError)")
    #expect(app.requests.received.isEmpty)
  }

  @Test func openingFromAHelperInNoBundleSaysSo() async throws {
    let output = try await HelperBinary.run(
      ["open"],
      environment: [Helper.controlSocketVariable: "/tmp/ms-nobody.sock"],
    )

    #expect(output.status == 1)
    #expect(output.standardError.contains("in no app bundle"), "\(output.standardError)")
  }
}
