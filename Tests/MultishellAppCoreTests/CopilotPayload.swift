import MultishellCore

/// Copilot 1.0.87's own payloads, captured from `copilot -p` spawning one
/// subagent, driven through the report the helper builds and into the model.
enum CopilotPayload {
  static let copilot = AgentHookCatalogue.integration("copilot")!
  static let parent = "17954dff-e162-4e7a-925e-a59ca530c5fb"
  static let child = "37880ecf-c5f3-42ce-afe0-82b221d75839"
  static let transcript = "/Users/dev/.copilot/session-state/\(parent)/events.jsonl"

  static let sessionStart =
    #"{"hook_event_name":"SessionStart","session_id":"\#(parent)","cwd":"/w","source":"new"}"#
  static let prompt =
    #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(parent)","cwd":"/w","prompt":"go"}"#
  static let taskCall =
    #"{"hook_event_name":"PreToolUse","session_id":"\#(parent)","cwd":"/w","tool_name":"Agent"}"#
  static let subagentStart =
    #"{"sessionId":"\#(parent)","cwd":"/w","transcriptPath":"\#(transcript)","agentName":"general-purpose"}"#
  static let childPrompt =
    #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(child)","cwd":"/w","prompt":"sub"}"#
  static let childTool =
    #"{"hook_event_name":"PreToolUse","session_id":"\#(child)","cwd":"/w","tool_name":"Bash"}"#
  static let childStop =
    #"{"hook_event_name":"Stop","session_id":"\#(child)","cwd":"/w","transcript_path":"\#(transcript)","stop_reason":"end_turn"}"#
  static let subagentStop =
    #"{"hook_event_name":"SubagentStop","session_id":"\#(parent)","cwd":"/w","transcript_path":"\#(transcript)","agent_id":"\#(child)","agent_type":"general-purpose","agent_name":"general-purpose","stop_reason":"end_turn"}"#
  static let taskDone =
    #"{"hook_event_name":"PostToolUse","session_id":"\#(parent)","cwd":"/w","tool_name":"Agent"}"#
  static let stop =
    #"{"hook_event_name":"Stop","session_id":"\#(parent)","cwd":"/w","transcript_path":"\#(transcript)","stop_reason":"end_turn"}"#
}
