import Foundation

/// A coding agent the app knows how to start.
public struct AgentDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  /// Looked up on the login shell's PATH.
  public let executable: String
  public let launchArguments: [String]
  /// How to pick the last conversation up again when a saved agent tab
  /// comes back after a relaunch. `nil` means the agent has no such flag
  /// and the tab comes back as a plain shell.
  public let resumeArguments: [String]?
  /// How this agent is told about a file at its prompt: `@` for one that
  /// reads mentions. `nil` means it is told nothing special, and a file
  /// dropped on its tab arrives as a plain path, which any agent can read.
  /// Only set it for an agent whose prompt is known to resolve them.
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
    AgentDescriptor(id: "gemini", name: "Gemini CLI", executable: "gemini"),
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
