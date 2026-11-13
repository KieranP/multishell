import Foundation
import Testing

@testable import MultishellProcess

extension ProcessRunnerTests {
  @Test func aMissingExecutableThrowsBeforeAnythingRuns() async {
    await #expect(throws: (any Error).self) {
      try await runner.run(URL(fileURLWithPath: "/no/such/binary"), [], in: workingDirectory)
    }
  }

  /// Read as the signal's own number, SIGINT's 2 was git's "no such branch" and
  /// SIGHUP's 1 a "not an ancestor"; a shell's 128 plus the signal is neither.
  @Test func aChildKilledByASignalReadsAsTheShellsStatusForIt() async throws {
    let output = try await runner.capture(
      bourneShell,
      ["-c", "kill -INT $$"],
      in: workingDirectory,
    )

    #expect(output.status == 128 + SIGINT)
  }

  @Test func aMissingWorkingDirectoryThrows() async {
    await #expect(throws: (any Error).self) {
      try await runner.run(bourneShell, ["-c", "true"], in: URL(fileURLWithPath: "/no/such/dir"))
    }
  }

  /// Each failure used to leak six descriptors, every five seconds on an unmounted drive. Other
  /// suites' descriptors come and go, so each side is the lowest reading over seconds.
  @Test func failedLaunchesDoNotLeakFileDescriptors() async throws {
    func failToLaunch() async {
      _ = try? await runner.run(
        bourneShell,
        ["-c", "true"],
        in: URL(fileURLWithPath: "/no/such/dir"),
      )
    }

    for _ in 0..<5 { await failToLaunch() }
    let before = try await lowestDescriptorCount(over: .seconds(2))
    for _ in 0..<100 { await failToLaunch() }
    let after = try await lowestDescriptorCount(over: .seconds(4))

    #expect(after - before < 300, "before \(before), after \(after); the leak was 600")
  }
}
