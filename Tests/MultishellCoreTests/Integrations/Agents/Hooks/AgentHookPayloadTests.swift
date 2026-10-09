import Foundation
import Testing

@testable import MultishellCore

struct AgentHookPayloadTests {
  @Test func theStdinPayloadYieldsEventDirectoryAndMessage() throws {
    let payload = AgentHookPayload(
      json: Data(
        #"""
        { "session_id": "abc", "transcript_path": "/t", "cwd": "/w/repo",
          "hook_event_name": "Notification", "message": "Claude needs your permission",
          "notification_type": "permission_prompt" }
        """#.utf8
      )
    )
    #expect(payload?.eventName == "Notification")
    #expect(payload?.workingDirectory == "/w/repo")
    #expect(payload?.message == "Claude needs your permission")
    #expect(payload?.notificationType == "permission_prompt")
    #expect(AgentHookCatalogue.claude.event(for: try #require(payload))?.state == .attention)
  }

  /// It is why one parser serves all four agents.
  @Test func codexAndCopilotWriteTheSameFields() {
    let codex = AgentHookPayload(
      json: Data(
        #"""
        { "cwd": "/w/repo", "hook_event_name": "PermissionRequest", "model": "gpt-5",
          "permission_mode": "default", "session_id": "s", "transcript_path": null,
          "tool_name": "shell", "turn_id": "t" }
        """#.utf8
      )
    )
    #expect(codex?.eventName == "PermissionRequest")
    #expect(codex?.workingDirectory == "/w/repo")
    #expect(codex?.message == nil)

    let copilot = AgentHookPayload(
      json: Data(
        #"""
        { "sessionId": "s", "timestamp": 1, "cwd": "/w/repo",
          "hook_event_name": "Notification", "message": "Permission needed",
          "notification_type": "permission_prompt" }
        """#.utf8
      )
    )
    #expect(copilot?.eventName == "Notification")
    #expect(copilot?.workingDirectory == "/w/repo")
    #expect(copilot?.message == "Permission needed")
  }

  @Test func aPayloadWithoutAnEventNameIsNotAPayload() {
    #expect(AgentHookPayload(json: Data(#"{"cwd":"/w"}"#.utf8)) == nil)
    #expect(AgentHookPayload(json: Data("nope".utf8)) == nil)
    #expect(AgentHookPayload(json: Data()) == nil)
  }
}
