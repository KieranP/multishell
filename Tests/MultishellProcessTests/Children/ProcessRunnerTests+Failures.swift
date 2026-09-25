import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

extension ProcessRunnerTests {
  @Test func aMissingExecutableThrowsBeforeAnythingRuns() async {
    let runner = ProcessRunner()
    await #expect(throws: (any Error).self) {
      try await runner.run(
        URL(fileURLWithPath: "/no/such/binary"), [],
        in: URL(fileURLWithPath: NSTemporaryDirectory()))
    }
  }

  @Test func aMissingWorkingDirectoryThrows() async {
    let runner = ProcessRunner()
    await #expect(throws: (any Error).self) {
      try await runner.run(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "true"], in: URL(fileURLWithPath: "/no/such/dir"))
    }
  }

  /// Each failure used to leak six descriptors, every five seconds on an unmounted drive. Other
  /// suites' descriptors come and go, so each side is the lowest reading over seconds.
  @Test func failedLaunchesDoNotLeakFileDescriptors() async throws {
    let runner = ProcessRunner()
    func failToLaunch() async {
      _ = try? await runner.run(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "true"], in: URL(fileURLWithPath: "/no/such/dir"))
    }

    for _ in 0..<5 { await failToLaunch() }
    let before = try await lowestDescriptorCount(over: .seconds(2))
    for _ in 0..<100 { await failToLaunch() }
    let after = try await lowestDescriptorCount(over: .seconds(4))

    #expect(after - before < 300, "before \(before), after \(after); the leak was 600")
  }
}
