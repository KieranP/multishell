import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellGitKit

@Suite
struct GitRunnerRunLogTests {
  @Test func aRecordingLogTimesEveryRunUnderItsCommandAndDirectory() async throws {
    let directory = try Scratch.directory("gitrunlog")
    defer { Scratch.remove(directory) }
    let git = try Scratch.script("echo ran", at: directory.appendingPathComponent("git"))
    let log = GitRunLog()
    log.setRecording(true)
    let runner = try GitRunner(executable: git, runLog: log)

    _ = try await runner.run(["status", "--porcelain=v2"], in: directory)
    _ = await runner.output(["rev-parse", "HEAD"], in: directory)

    let activity = log.drain()
    #expect(activity.startedCount == 2)
    #expect(activity.runningCount == 0)
    #expect(activity.finishedRuns.map(\.command) == ["status --porcelain", "rev-parse"])
    #expect(activity.finishedRuns.allSatisfy { $0.directory == directory })
    #expect(activity.finishedRuns.allSatisfy { ($0.exitUsage?.peakFootprint ?? 0) > 0 })
    #expect(activity.finishedRuns.allSatisfy { ($0.exitUsage?.pid ?? 0) > 0 })
  }
}
