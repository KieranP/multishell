import Foundation
import Testing

@testable import MultishellCore

/// Lines in the shapes Claude Code 2.1 writes them, trimmed to the fields read.
struct ClaudeTranscriptPendingQuestionTests {
  private func call(_ id: String, _ name: String) -> String {
    #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"\#(id)","name":"\#(name)"}]}}"#
  }

  private func result(_ id: String) -> String {
    #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"\#(id)"}]}}"#
  }

  private func asksQuestion(_ lines: [String], startsAtFileStart: Bool = true) -> Bool {
    ClaudeTranscript.asksQuestion(
      in: Data(lines.joined(separator: "\n").utf8), startsAtFileStart: startsAtFileStart)
  }

  @Test func anUnansweredQuestionAfterAnsweredCallsIsStillAsked() {
    #expect(asksQuestion([call("t1", "Bash"), result("t1"), call("t2", "AskUserQuestion")]))
  }

  @Test func onlyTheLastCallCountsThoughAnEarlierQuestionIsUnanswered() {
    #expect(!asksQuestion([call("t1", "AskUserQuestion"), call("t2", "Bash")]))
  }

  @Test func aQuestionAnsweredOrNeverAskedIsNotAsked() {
    #expect(!asksQuestion([call("t1", "AskUserQuestion"), result("t1")]))
    #expect(!asksQuestion([#"{"type":"user","message":{"content":"hello"}}"#]))
    #expect(!asksQuestion([]))
  }

  @Test func aTailThatStartsMidLineSkipsThatLine() {
    let partial = call("t1", "AskUserQuestion")
    #expect(!asksQuestion([partial], startsAtFileStart: false))
    #expect(asksQuestion([partial, call("t2", "AskUserQuestion")], startsAtFileStart: false))
  }
}
