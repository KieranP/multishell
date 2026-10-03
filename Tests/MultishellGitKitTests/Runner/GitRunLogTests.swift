import Foundation
import Testing

@testable import MultishellGitKit

@Suite
struct GitRunLogTests {
  private let run = GitRun(
    command: "status", directory: URL(fileURLWithPath: "/tmp"), duration: .milliseconds(5),
    exitUsage: nil)

  @Test func aLogThatIsNotRecordingTimesNothing() {
    let log = GitRunLog()
    #expect(!log.beginRunIfRecording())
    log.endRun(run)
    #expect(log.drain() == .none)
  }

  @Test func aDrainHandsOverTheRunsSinceTheLastAndKeepsTheRunningCount() {
    let log = GitRunLog()
    log.setRecording(true)
    #expect(log.beginRunIfRecording())
    #expect(log.beginRunIfRecording())
    log.endRun(run)

    #expect(
      log.drain() == GitRunActivity(startedCount: 2, runningCount: 1, finishedRuns: [run]))
    #expect(log.drain() == GitRunActivity(startedCount: 0, runningCount: 1, finishedRuns: []))
  }

  @Test func turningRecordingOffDropsWhatWasKeptButARunStillInFlightFinishes() {
    let log = GitRunLog()
    log.setRecording(true)
    #expect(log.beginRunIfRecording())
    log.setRecording(false)
    log.endRun(run)
    log.setRecording(true)

    #expect(log.drain() == .none)
  }
}
