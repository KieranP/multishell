import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite
struct GitCommandTallyTests {
  @Test func runsAreGroupedByCommandWithTheirTotalMeanAndSlowestPlace() throws {
    let tallies = GitCommandTally.byCommand([
      GitRun.sample("status", milliseconds: 100, in: "/a"),
      GitRun.sample("status", milliseconds: 300, in: "/b"),
      GitRun.sample("fetch", milliseconds: 50, in: "/a"),
    ])

    let status = try #require(tallies["status"])
    #expect(status.runCount == 2)
    #expect(status.totalDuration == .milliseconds(400))
    #expect(status.meanDuration == .milliseconds(200))
    #expect(status.slowestDuration == .milliseconds(300))
    #expect(status.slowestDirectory?.path == "/b")
    #expect(tallies["fetch"]?.runCount == 1)
  }

  @Test func mergingKeepsTheSlowerOfTheTwoSlowestRuns() {
    var first = GitCommandTally.byCommand([GitRun.sample("status", milliseconds: 300, in: "/a")])[
      "status"]!
    let second = GitCommandTally.byCommand([GitRun.sample("status", milliseconds: 100, in: "/b")])[
      "status"]!
    first.merge(second)
    #expect(first.runCount == 2)
    #expect(first.slowestDirectory?.path == "/a")
    #expect(GitCommandTally().meanDuration == .zero)
  }

  @Test func memoryIsTheMeanAndHighestPeakOfTheRunsWhosePeakWasRead() throws {
    let tallies = GitCommandTally.byCommand([
      GitRun.sample("status", milliseconds: 10, in: "/a", peakMemory: 2_000),
      GitRun.sample("status", milliseconds: 10, in: "/a", peakMemory: 6_000),
      GitRun.sample("status", milliseconds: 10, in: "/a"),
    ])

    let status = try #require(tallies["status"])
    #expect(status.meanPeakMemory == 4_000)
    #expect(status.peakMemory == 6_000)
    #expect(GitCommandTally().meanPeakMemory == nil)
    #expect(GitCommandTally().peakMemory == nil)
  }
}
