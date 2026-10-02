import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Lines in the shapes Claude Code 2.1 writes them, trimmed to the fields read.
struct ClaudeTranscriptTests {
  private func notice(_ id: String) -> String {
    "<task-notification>\\n<task-id>\(id)</task-id>\\n<status>completed</status>"
  }

  private func queued(_ id: String, at time: String) -> String {
    #"{"type":"queue-operation","operation":"enqueue","timestamp":"\#(time)","content":"\#(notice(id))"}"#
  }

  private func stopped(at time: String) -> String {
    #"{"type":"system","subtype":"stop_hook_summary","timestamp":"\#(time)"}"#
  }

  private func lines(_ lines: [String]) -> Data { Data(lines.joined(separator: "\n").utf8) }

  @Test func aNoticeQueuedSinceTheLastStopAndNotYetDeliveredMeansATurnFollows() {
    let data = lines([
      stopped(at: "2026-09-30T10:00:00.000Z"),
      queued("a1", at: "2026-09-30T10:00:05.000Z"),
    ])
    #expect(ClaudeTranscript.turnFollows(in: data, startsAtFileStart: true))
  }

  @Test func aNoticeDeliveredInAnyOfItsThreeWaysMeansNoTurnFollows() {
    let deliveries = [
      #"{"type":"queue-operation","operation":"remove","timestamp":"2026-09-30T10:00:06.000Z","content":"\#(notice("a1"))"}"#,
      #"{"type":"attachment","timestamp":"2026-09-30T10:00:06.000Z","attachment":{"type":"queued_command","prompt":"\#(notice("a1"))"}}"#,
      #"{"type":"user","timestamp":"2026-09-30T10:00:06.000Z","message":{"content":"\#(notice("a1"))"}}"#,
    ]
    for delivery in deliveries {
      let data = lines([queued("a1", at: "2026-09-30T10:00:05.000Z"), delivery])
      #expect(!ClaudeTranscript.turnFollows(in: data, startsAtFileStart: true), "\(delivery)")
    }
  }

  @Test func aNoticeQueuedBeforeTheLastStopIsThatStopsAndNotThisOnes() {
    let data = lines([
      queued("a1", at: "2026-09-30T10:00:05.000Z"),
      stopped(at: "2026-09-30T10:00:06.000Z"),
    ])
    #expect(!ClaudeTranscript.turnFollows(in: data, startsAtFileStart: true))
  }

  @Test func aNoticeQuotedInsideSomethingElseQueuesNothing() {
    let data = lines([
      #"{"type":"assistant","timestamp":"2026-09-30T10:00:05.000Z","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"echo '\#(notice("a1"))'"}}]}}"#,
      #"{"type":"queue-operation","operation":"enqueue","timestamp":"2026-09-30T10:00:05.000Z","content":"see \#(notice("a2"))"}"#,
    ])
    #expect(!ClaudeTranscript.turnFollows(in: data, startsAtFileStart: true))
  }

  @Test func aTailThatStartsMidLineSkipsThatLine() {
    let data = lines([
      #"mary","timestamp":"2026-09-30T10:00:09.000Z"}"#,
      queued("a1", at: "2026-09-30T10:00:05.000Z"),
    ])
    #expect(ClaudeTranscript.turnFollows(in: data, startsAtFileStart: false))
  }

  @Test func aFileIsReadFromItsTailAndAMissingOneSaysNothing() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let file = directory.appendingPathComponent("session.jsonl")
    let filler =
      #"{"type":"user","message":{"content":""#
      + String(
        repeating: "x", count: ClaudeTranscript.tailBytes) + #""}}"#
    try lines([
      stopped(at: "2026-09-30T10:00:00.000Z"), filler, queued("a1", at: "2026-09-30T10:00:05.000Z"),
    ])
    .write(to: file)
    #expect(ClaudeTranscript.turnFollows(atPath: file.path))
    #expect(!ClaudeTranscript.turnFollows(atPath: directory.appendingPathComponent("none").path))
  }
}
