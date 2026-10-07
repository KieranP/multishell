import Foundation

extension ProjectSettings {
  /// Renamed fields keep their old keys; a new key would drop every trust
  /// answer, shell and auto-start choice already saved.
  enum CodingKeys: String, CodingKey {
    case worktreeDirectory, branchPrefix, defaultBranch
    case preCreateHook, postCreateHook, preDeleteHook, postDeleteHook
    case linkedPaths, copiedPaths
    case preferredAgentID, agentFlags
    case autoStartsAgent = "autoStartAgent"
    case autoStartsAgentOnCreate = "autoStartAgentOnCreate"
    case opensTerminalOnSelect, worktreeSortOrder, showsActiveWorktreesFirst, opensTerminalOnCreate
    case preferredShellID = "defaultShell"
    case iconGlyph, iconTint
    case trustDecisions = "sharedHooks"
  }

  /// `""` overrides to "none" for the four fields with no other spelling for
  /// it, and is noise elsewhere; see Docs/design/settings.md.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    worktreeDirectory = try container.decodeIfPresent(String.self, forKey: .worktreeDirectory)
    branchPrefix = try container.decodeIfPresent(String.self, forKey: .branchPrefix)
    defaultBranch = try container.decodeIfPresent(String.self, forKey: .defaultBranch)
    preCreateHook = try container.decode(String.self, forKey: .preCreateHook, or: "")
    postCreateHook = try container.decode(String.self, forKey: .postCreateHook, or: "")
    preDeleteHook = try container.decode(String.self, forKey: .preDeleteHook, or: "")
    postDeleteHook = try container.decode(String.self, forKey: .postDeleteHook, or: "")
    linkedPaths = try container.decode(String.self, forKey: .linkedPaths, or: "")
    copiedPaths = try container.decode(String.self, forKey: .copiedPaths, or: "")
    preferredAgentID = try container.decodeIfPresent(
      String.self, forKey: .preferredAgentID)?.nonEmpty
    // No `nonEmpty`: `""` is this field's only way to say "no flags here".
    agentFlags = try container.decodeIfPresent(String.self, forKey: .agentFlags)
    autoStartsAgent = try container.decodeIfPresent(Bool.self, forKey: .autoStartsAgent)
    // Absent is "follow the global", not "what `autoStartsAgent` says": seeding
    // it from the other turns the global into an override on every load.
    autoStartsAgentOnCreate = try container.decodeIfPresent(
      Bool.self, forKey: .autoStartsAgentOnCreate)
    opensTerminalOnSelect = try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect)
    opensTerminalOnCreate = try container.decodeIfPresent(Bool.self, forKey: .opensTerminalOnCreate)
    // Tolerated: an order a newer build named costs the override, not the project.
    worktreeSortOrder = container.decodeTolerantly(
      WorktreeSortOrder.self, forKey: .worktreeSortOrder)
    showsActiveWorktreesFirst = try container.decodeIfPresent(
      Bool.self, forKey: .showsActiveWorktreesFirst)
    preferredShellID = try container.decodeIfPresent(
      String.self, forKey: .preferredShellID)?.nonEmpty
    iconGlyph = try container.decodeIfPresent(String.self, forKey: .iconGlyph)?.nonEmpty
    // Tolerated: a tint that is not a number costs the tint, not the file.
    iconTint = ProjectIcon.usableTint(container.decodeTolerantly(Int.self, forKey: .iconTint))
    // Lossy: an answer that will not decode costs that answer and not the
    // project's others, and its hooks are asked about again.
    trustDecisions = container.decodeLossy(
      TrustDecision.self, forKey: .trustDecisions)
  }
}
