/// Copilot 1.0.87's own payloads, captured from `copilot -p` spawning one
/// subagent.
public enum CopilotPayload {
  public static let parent = "17954dff-e162-4e7a-925e-a59ca530c5fb"
  public static let child = "37880ecf-c5f3-42ce-afe0-82b221d75839"
  public static let transcript = "/Users/dev/.copilot/session-state/\(parent)/events.jsonl"

  public static let sessionStart =
    #"{"hook_event_name":"SessionStart","session_id":"\#(parent)","cwd":"/w","source":"new"}"#
  public static let prompt =
    #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(parent)","cwd":"/w","prompt":"go"}"#
  public static let taskCall =
    #"{"hook_event_name":"PreToolUse","session_id":"\#(parent)","cwd":"/w","tool_name":"Agent"}"#
  public static let subagentStart =
    #"{"sessionId":"\#(parent)","cwd":"/w","transcriptPath":"\#(transcript)","agentName":"general-purpose"}"#
  public static let childPrompt =
    #"{"hook_event_name":"UserPromptSubmit","session_id":"\#(child)","cwd":"/w","prompt":"sub"}"#
  public static let childTool =
    #"{"hook_event_name":"PreToolUse","session_id":"\#(child)","cwd":"/w","tool_name":"Bash"}"#
  public static let childStop =
    #"{"hook_event_name":"Stop","session_id":"\#(child)","cwd":"/w","transcript_path":"\#(transcript)","stop_reason":"end_turn"}"#
  public static let subagentStop =
    #"{"hook_event_name":"SubagentStop","session_id":"\#(parent)","cwd":"/w","transcript_path":"\#(transcript)","agent_id":"\#(child)","agent_type":"general-purpose","agent_name":"general-purpose","stop_reason":"end_turn"}"#
  public static let taskDone =
    #"{"hook_event_name":"PostToolUse","session_id":"\#(parent)","cwd":"/w","tool_name":"Agent"}"#
  public static let stop =
    #"{"hook_event_name":"Stop","session_id":"\#(parent)","cwd":"/w","transcript_path":"\#(transcript)","stop_reason":"end_turn"}"#
}
