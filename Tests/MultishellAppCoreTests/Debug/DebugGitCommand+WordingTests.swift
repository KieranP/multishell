import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct DebugGitCommandWordingTests {
  private func row(peakMemory: UInt64?, location: DebugLocation?) -> DebugGitCommand {
    let run = GitRun.sample(peakMemory: peakMemory)
    return DebugGitCommand(
      command: "status", tally: GitCommandTally.byCommand([run, run])["status"]!,
      slowestLocation: location)
  }

  @Test func aNarrowRowSaysItsRunsTimesAndWhereTheSlowestRan() {
    let located = row(
      peakMemory: nil, location: DebugLocation(projectName: "acme", worktreeName: "main"))
    #expect(located.timingSummary == "2 runs · mean 150 ms · slowest 150 ms in acme / main")
    #expect(row(peakMemory: nil, location: nil).timingSummary.hasSuffix("slowest 150 ms"))
  }

  @Test func memoryIsSaidOnlyWhereARunsPeakWasRead() {
    #expect(row(peakMemory: nil, location: nil).memorySummary == nil)
    #expect(row(peakMemory: 4_096, location: nil).memorySummary?.hasPrefix("Memory ") == true)
  }
}
