import Foundation
import Testing

@testable import MultishellCore

@Suite
struct AgentHookPayloadAntigravityTests {
  private static let antigravity = AgentHookCatalogue.antigravity

  /// Antigravity 1.4.8's Stop, as its hook read it on stdin on 2026-10-27.
  private static func stop(reason: String) -> Data {
    Data(
      #"""
      {"artifactDirectoryPath":"/Users/me/.gemini/antigravity-cli/brain/652e","conversationId":"652e",
       "error":"","executionNum":0,"fullyIdle":true,"lastUserInput":"run it",
       "modelName":"gemini-3.8-flash-high","terminationReason":"\#(reason)",
       "transcriptPath":"/Users/me/.gemini/antigravity-cli/brain/652e/.system_generated/logs/transcript_full.jsonl",
       "workspacePaths":["/w/repo","/w/other"]}
      """#.utf8
    )
  }

  private static func report(_ payload: AgentHookPayload) -> SessionStateReport? {
    antigravity.report(for: payload, sessionID: nil, workingDirectory: nil, pid: nil)
  }

  @Test func theEventComesFromTheHookLineAndTheDirectoryFromTheFirstWorkspace() throws {
    let payload = try #require(
      Self.antigravity.payload(json: Self.stop(reason: "NO_TOOL_CALL"), eventName: "Stop")
    )
    #expect(payload.eventName == "Stop")
    #expect(payload.workingDirectory == "/w/repo")
  }

  @Test func aStopIsDoneOneTheUserCancelledIsIdleAndOneThatFailedIsAnError() throws {
    func state(_ reason: String) throws -> SessionState? {
      let payload = try #require(
        Self.antigravity.payload(json: Self.stop(reason: reason), eventName: "Stop")
      )
      return Self.report(payload)?.state
    }
    #expect(try state("NO_TOOL_CALL") == .done)
    #expect(try state("USER_CANCELED") == .idle)
    #expect(try state("ERROR") == .failed)
  }

  @Test func eachModelCallStartsATurnAndEachToolCallSaysWorking() throws {
    let invocation = Data(#"{"conversationId":"c","invocationNum":1,"workspacePaths":["/w"]}"#.utf8)
    let tool = Data(
      #"{"conversationId":"c","stepIdx":2,"toolCall":{"name":"run_command","args":{}},"workspacePaths":["/w"]}"#
        .utf8
    )
    let started = try #require(
      Self.antigravity.payload(json: invocation, eventName: "PreInvocation")
    )
    let called = try #require(Self.antigravity.payload(json: tool, eventName: "PreToolUse"))
    let turn = Self.report(started)
    let call = Self.report(called)
    #expect(turn?.state == .running)
    #expect(turn?.startsTurn == true)
    #expect(call?.state == .running)
    #expect(call?.startsTurn == nil)
  }

  /// A background command's PostToolUse arrives when it exits, after the Stop,
  /// and would put a finished pane back to Working.
  @Test func aToolsEndIsNotAskedFor() throws {
    let payload = try #require(
      Self.antigravity.payload(
        json: Data(#"{"workspacePaths":["/w"]}"#.utf8),
        eventName: "PostToolUse",
      )
    )
    #expect(!Self.antigravity.asksFor(payload))
  }

  @Test func aLineNamingNoEventOrAPayloadThatIsNotAnObjectIsNotAPayload() {
    let data = Self.stop(reason: "NO_TOOL_CALL")
    #expect(Self.antigravity.payload(json: data, eventName: nil) == nil)
    #expect(Self.antigravity.payload(json: Data("nope".utf8), eventName: "Stop") == nil)
    #expect(
      AgentHookCatalogue.claude.payload(json: data, eventName: "Stop") == nil,
      "no hook_event_name",
    )
  }

  @Test func aFailedStopSaysWhatFailed() throws {
    let data = Data(
      #"{"terminationReason":"ERROR","error":"quota exceeded","workspacePaths":["/w"]}"#.utf8
    )
    let payload = try #require(Self.antigravity.payload(json: data, eventName: "Stop"))
    #expect(Self.report(payload)?.message == "quota exceeded")
    let quiet = try #require(
      Self.antigravity.payload(json: Self.stop(reason: "ERROR"), eventName: "Stop")
    )
    #expect(Self.report(quiet)?.message == nil, "an empty error is no message")
  }

  @Test func onlyAFailedStopsErrorIsItsMessage() throws {
    let canceled = Data(
      #"{"terminationReason":"USER_CANCELED","error":"canceled by user","workspacePaths":["/w"]}"#
        .utf8
    )
    let payload = try #require(Self.antigravity.payload(json: canceled, eventName: "Stop"))
    #expect(Self.report(payload)?.message == nil)
  }
}
