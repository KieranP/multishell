import Foundation
import Testing

@testable import MultishellServices

@Suite
struct ServiceToolRunnerTests {
  private func runner(for tool: FakeTool) -> ServiceToolRunner {
    ServiceToolRunner(
      executable: tool.executable,
      searchPath: nil,
      quietEnvironment: [:],
      runLog: tool.runLog,
      loginVariables: [:],
    )
  }

  @Test func aToolThatFailsSayingNothingOnStderrIsWordedByWhatItDidSay() async throws {
    let tool = try FakeTool(named: "gh", "echo 'not a git repository'; exit 1")
    defer { tool.tearDown() }

    await #expect(throws: ServiceReadFailure.failed("not a git repository")) {
      try await runner(for: tool).read(["pr", "list"], in: tool.directory) { .failed($0) }
    }
  }

  @Test func aToolThatFailsSayingNothingAtAllIsWordedByItsExit() async throws {
    let tool = try FakeTool(named: "gh", "exit 4")
    defer { tool.tearDown() }

    await #expect(throws: ServiceReadFailure.failed("gh exited with status 4")) {
      try await runner(for: tool).read(["pr", "list"], in: tool.directory) { .failed($0) }
    }
  }

  @Test func aToolThatCannotBeRunSaysSoInWords() async throws {
    let tool = try FakeTool(named: "gh", "exit 0")
    defer { tool.tearDown() }
    let missing = ServiceToolRunner(
      executable: tool.directory.appendingPathComponent("gone"),
      searchPath: nil,
      quietEnvironment: [:],
      runLog: tool.runLog,
      loginVariables: [:],
    )

    await #expect(throws: ServiceReadFailure.failed("gone could not be run")) {
      try await missing.read(["pr", "list"], in: tool.directory) { .failed($0) }
    }
  }
}
