import Foundation
import Testing

@testable import MultishellProcess

extension ProcessRunnerTests {
  @Test func aRunAskedForItsChildsUsageReadsItAsTheChildExits() async throws {
    let probe = ExitUsageProbe()
    _ = try await runner.run(
      sh, ["-c", "i=0; while [ $i -lt 20000 ]; do i=$((i+1)); done"], in: workingDirectory,
      exitUsage: probe)

    let usage = try #require(probe.usage)
    #expect(usage.pid > 0)
    #expect(usage.peakFootprint > 0)
    #expect(usage.cpuTime > .zero)
    #expect(ExitUsageProbe().usage == nil)
  }
}
