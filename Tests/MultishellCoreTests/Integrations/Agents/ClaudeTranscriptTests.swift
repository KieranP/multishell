import Foundation
import Testing

@testable import MultishellCore

/// Lines in the shapes Claude Code 2.1 writes them, trimmed to the fields read.
struct ClaudeTranscriptTests: AgentHookFixtures {
  private func notice(_ id: String) -> String {
    "<task-notification>\\n<task-id>\(id)</task-id>\\n<status>completed</status>"
  }

  private func toolCall(_ name: String, _ input: String) -> String {
    #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":""#
      + name + #"","input":"# + input + "}]}}"
  }

  private func lines(_ lines: [String]) -> Data { Data(lines.joined(separator: "\n").utf8) }

  @Test func aNoticeInAnyOfItsThreeShapesOrATaskStopEndsAWorker() {
    let data = lines([
      #"{"type":"queue-operation","operation":"enqueue","content":"\#(notice("a1"))"}"#,
      #"{"type":"user","message":{"role":"user","content":"\#(notice("a2"))"}}"#,
      #"{"type":"attachment","attachment":{"type":"queued_command","prompt":"\#(notice("a3"))"}}"#,
      toolCall("TaskStop", #"{"task_id":"a4"}"#),
    ])
    #expect(ClaudeTranscript.endedWorkers(in: data, fromStart: true) == ["a1", "a2", "a3", "a4"])
  }

  @Test func aMessageSentToAnEndedWorkerStartsItAgainUntilItsNextNotice() {
    let data = lines([
      #"{"type":"user","message":{"content":"\#(notice("a1"))"}}"#,
      #"{"type":"user","message":{"content":"\#(notice("a2"))"}}"#,
      toolCall("SendMessage", #"{"to":"a1","message":"go on"}"#),
      toolCall("SendMessage", #"{"to":"a2","message":"go on"}"#),
      #"{"type":"queue-operation","operation":"enqueue","content":"\#(notice("a2"))"}"#,
    ])
    #expect(ClaudeTranscript.endedWorkers(in: data, fromStart: true) == ["a2"])
  }

  @Test func aNoticeQuotedInsideSomethingElseEndsNothing() {
    let data = lines([
      toolCall("Bash", #"{"command":"echo '\#(notice("a1"))'"}"#),
      #"{"type":"user","message":{"content":"see \#(notice("a2"))"}}"#,
      #"{"type":"user","message":{"content":[{"type":"tool_result","content":"\#(notice("a3"))"}]}}"#,
    ])
    #expect(ClaudeTranscript.endedWorkers(in: data, fromStart: true).isEmpty)
  }

  @Test func aTailThatStartsMidLineSkipsThatLine() {
    let data = lines([
      #"":"\#(notice("a1"))"}"#,
      #"{"type":"user","message":{"content":"\#(notice("a2"))"}}"#,
    ])
    #expect(ClaudeTranscript.endedWorkers(in: data, fromStart: false) == ["a2"])
  }

  @Test func aFileIsReadFromItsTailAndAMissingOneSaysNothing() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("session.jsonl")
    let filler = String(repeating: "x", count: ClaudeTranscript.tailBytes)
    try lines([
      #"{"type":"user","message":{"content":"\#(notice("a1"))"}}"#,
      #"{"type":"user","message":{"content":"\#(filler)"}}"#,
      #"{"type":"user","message":{"content":"\#(notice("a2"))"}}"#,
    ]).write(to: file)
    #expect(ClaudeTranscript.endedWorkers(atPath: file.path) == ["a2"], "a1 is past the tail")
    #expect(
      ClaudeTranscript.endedWorkers(atPath: directory.appendingPathComponent("none").path) == nil)
  }
}
