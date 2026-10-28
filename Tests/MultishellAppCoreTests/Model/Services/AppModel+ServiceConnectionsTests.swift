import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite(.serialized) @MainActor
struct AppModelServiceConnectionsTests {
  @Test func anIntegrationsPageOpenedBeforeTheToolsWereFoundHearsFromThemOnceTheyAre() async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    _ = try Scratch.script(
      """
      case "$1" in
        --version) echo 'gh version 2.60.0 (2026-01-01)' ;;
        auth) echo 'Logged in to github.com account tester' ;;
      esac
      """,
      at: tools.appendingPathComponent("gh"),
    )
    await harness.model.refreshServiceToolStatuses()

    await harness.model.adoptServiceTools(on: tools.path)

    try await waitUntil { harness.model.integrationAvailability(.gitHub) != .checking }
    #expect(harness.model.integrationAvailability(.gitHub) != .checking)
  }

  @Test func anInstalledToolWithoutGitSaysSoRatherThanChecking() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    _ = try Scratch.script(
      "echo 'gh version 2.60.0 (2026-01-01)'",
      at: tools.appendingPathComponent("gh"),
    )
    harness.model.coordinator = nil
    await harness.model.adoptServiceTools(on: tools.path)

    await harness.model.refreshServiceToolStatuses()

    #expect(harness.model.integrationAvailability(.gitHub) == .needsGit)
  }

  @Test func theSameToolsFoundAgainOnceGitIsFoundAreConnected() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    _ = try Scratch.script(
      "echo 'gh version 2.60.0 (2026-01-01)'",
      at: tools.appendingPathComponent("gh"),
    )
    let coordinator = harness.model.coordinator
    harness.model.coordinator = nil
    await harness.model.adoptServiceTools(on: tools.path)
    harness.model.coordinator = coordinator

    await harness.model.adoptServiceTools(on: tools.path)

    #expect(harness.model.remoteState.connections.pullRequestHosts[.gitHub] != nil)
  }

  @Test func aSlowCheckOfAnEarlierToolCannotOverwriteTheNewOnesVerdict() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let old = try Scratch.directory("old-tools")
    defer { Scratch.remove(old) }
    let new = try Scratch.directory("new-tools")
    defer { Scratch.remove(new) }
    let started = old.appendingPathComponent("started")
    _ = try Scratch.script(
      "/usr/bin/touch '\(started.path)'; /bin/sleep 1; echo 0.1.2",
      at: old.appendingPathComponent("circleci"),
    )
    _ = try Scratch.script("echo 'circleci 1.11.0'", at: new.appendingPathComponent("circleci"))
    await harness.model.adoptServiceTools(on: old.path)
    try await waitUntil { FileManager.default.fileExists(atPath: started.path) }

    await harness.model.adoptServiceTools(on: new.path)
    try await waitUntil { !harness.model.remoteState.unreadableProviders.contains(.circleCI) }
    try await waitUntil(
      { harness.model.remoteState.unreadableProviders.contains(.circleCI) },
      seconds: 3,
    )

    #expect(!harness.model.remoteState.unreadableProviders.contains(.circleCI))
  }

  @Test func anAskBegunBeforeTheToolsWereFoundCannotOverwriteTheirAnswers() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (host, _) = harness.connectServices()
    defer { host.releaseHeldReads() }
    host.holdToolStatus()
    let early = Task { await harness.model.refreshServiceToolStatuses() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    _ = try Scratch.script(
      """
      case "$1" in
        --version) echo 'gh version 2.60.0 (2026-01-01)' ;;
        auth) echo 'Logged in to github.com account tester' ;;
      esac
      """,
      at: tools.appendingPathComponent("gh"),
    )
    await harness.model.adoptServiceTools(on: tools.path)
    try await waitUntil { harness.model.integrationAvailability(.gitHub) != .checking }
    let found = harness.model.integrationAvailability(.gitHub)

    host.releaseHeldReads()
    await early.value

    #expect(harness.model.integrationAvailability(.gitHub) == found)
  }

  @Test func findingTheToolsWaitsOnNoVersionAnswerAndReadsNoCIUntilItComes() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    let gate = tools.appendingPathComponent("go")
    _ = try Scratch.script(
      """
      case "$1" in
        version) \(harness.holdLine(until: gate)); echo 'circleci 1.11.0 (abc)' ;;
      esac
      """,
      at: tools.appendingPathComponent("circleci"),
    )

    await harness.model.adoptServiceTools(on: tools.path)

    #expect(!harness.model.showsCIPanelPage, "unknown until circleci says its version")
    try "".write(to: gate, atomically: true, encoding: .utf8)
    try await waitUntil { harness.model.showsCIPanelPage }
    #expect(harness.model.showsCIPanelPage)
  }

  @Test func aProviderFoundAbleToReadIsReadAtOnceNotAnIntervalLater() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let tools = try Scratch.directory("tools")
    defer { Scratch.remove(tools) }
    let gate = tools.appendingPathComponent("go")
    let calls = tools.appendingPathComponent("calls")
    try FileManager.default.createDirectory(
      at: harness.project.path.appendingPathComponent(".circleci"),
      withIntermediateDirectories: true,
    )
    try "".write(
      to: harness.project.path.appendingPathComponent(".circleci/config.yml"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try Scratch.script("echo '[]'", at: tools.appendingPathComponent("gh"))
    _ = try Scratch.script(
      """
      echo "$*" >> "\(calls.path)"
      case "$1" in
        version) \(harness.holdLine(until: gate)); echo 'circleci 1.11.0 (abc)' ;;
        *) echo '[]' ;;
      esac
      """,
      at: tools.appendingPathComponent("circleci"),
    )
    await harness.model.adoptServiceTools(on: tools.path)
    await harness.model.pollServices()

    try "".write(to: gate, atomically: true, encoding: .utf8)

    try await waitUntil {
      ((try? String(contentsOf: calls, encoding: .utf8)) ?? "").contains("run list")
    }
    #expect(((try? String(contentsOf: calls, encoding: .utf8)) ?? "").contains("run list"))
  }

  @Test func anIntegrationsPageClosedAsksNothingMoreWhenToolsAreFound() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.refreshServiceToolStatuses()

    harness.model.stopAskingToolStatuses()

    #expect(!harness.model.remoteState.wantsToolStatuses)
  }
}
