import Foundation

/// A coding agent the app knows how to start.
public struct AgentDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  /// Looked up on the login shell's PATH.
  public let executable: String
  public let launchArguments: [String]
  /// How to resume the last conversation when a saved agent tab comes back.
  /// `nil` means the tab returns as a plain shell.
  public let resumeArguments: [String]?
  /// How this agent is told about a file: `@` for one that reads mentions,
  /// `nil` for a plain path. Only set where the prompt is known to resolve.
  public let fileMentionPrefix: String?

  public init(
    id: String, name: String, executable: String, launchArguments: [String] = [],
    resumeArguments: [String]? = nil, fileMentionPrefix: String? = nil
  ) {
    self.id = id
    self.name = name
    self.executable = executable
    self.launchArguments = launchArguments
    self.resumeArguments = resumeArguments
    self.fileMentionPrefix = fileMentionPrefix
  }
}

/// The agents people install, as a static table. Ids are strings in the
/// workspace so a newer build's agent loads harmlessly on an older one.
public enum AgentCatalogue {
  /// A project override that means "no agent here" while the global says
  /// otherwise. A global value of `nil` means the same.
  public static let noneID = "none"
  /// The command the user typed in settings, run as written.
  public static let customID = "custom"
  public static let claudeID = "claude"

  public static let agents: [AgentDescriptor] = [
    AgentDescriptor(
      id: claudeID, name: "Claude Code", executable: "claude", resumeArguments: ["--continue"],
      fileMentionPrefix: "@"),
    AgentDescriptor(
      id: "codex", name: "Codex", executable: "codex", resumeArguments: ["resume", "--last"]),
    AgentDescriptor(
      id: "gemini", name: "Gemini CLI", executable: "gemini",
      resumeArguments: ["--resume", "latest"]),
    AgentDescriptor(
      id: "copilot", name: "Copilot CLI", executable: "copilot", resumeArguments: ["--continue"]),
    AgentDescriptor(id: "aider", name: "Aider", executable: "aider"),
    AgentDescriptor(
      id: "opencode", name: "OpenCode", executable: "opencode", resumeArguments: ["--continue"]),
    AgentDescriptor(id: "cursor-agent", name: "Cursor Agent", executable: "cursor-agent"),
  ]

  public static func agent(_ id: String) -> AgentDescriptor? {
    agents.first { $0.id == id }
  }

  /// The id in force for a project: its override when it has one, else the
  /// global. `nil` means no agent, whichever side said so.
  public static func effectiveID(global: String?, override: String?) -> String? {
    let chosen = override ?? global
    guard let chosen, !chosen.isEmpty, chosen != noneID else { return nil }
    return chosen
  }
}
