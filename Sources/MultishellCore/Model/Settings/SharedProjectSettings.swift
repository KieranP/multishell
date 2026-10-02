import Foundation

/// Settings a repository ships for everyone who adds it, read as defaults
/// under the user's own and trusted before running; see settings.md.
public struct SharedProjectSettings: Codable, Equatable, Sendable {
  /// Absent leaves the user's value standing; blank is an opinion, the only
  /// spelling these three have for "none". Every reader trims.
  public internal(set) var worktreeDirectory: String?
  public internal(set) var branchPrefix: String?
  public internal(set) var defaultBranch: String?
  /// What a worktree here opens, and whether it runs the agent: a team may
  /// ship "a worktree comes up with an agent working in it".
  public internal(set) var autoStartsAgent: Bool?
  public internal(set) var autoStartsAgentOnCreate: Bool?
  public internal(set) var opensTerminalOnSelect: Bool?
  public internal(set) var opensTerminalOnCreate: Bool?
  public internal(set) var preCreateHook: String?
  public internal(set) var postCreateHook: String?
  public internal(set) var preDeleteHook: String?
  public internal(set) var postDeleteHook: String?
  /// Paths a new worktree is symlinked to, and paths copied. A repository may
  /// name only what is under it; `confined(to:)` drops the rest.
  public internal(set) var linkedPaths: String?
  public internal(set) var copiedPaths: String?
  /// What order a project's worktree rows come in. Display only, changing
  /// nothing the repository wrote on the reader's disk.
  public internal(set) var worktreeSortOrder: WorktreeSortOrder?
  public internal(set) var showsActiveWorktreesFirst: Bool?
  public internal(set) var iconGlyph: String?
  public internal(set) var iconTint: Int?

  /// The sha256 the trust decision is stored against; `nil` trusts nothing.
  /// Taken from the bytes by `load` and `fileContents`, as it decides what is trusted.
  public internal(set) var digest: String?
  /// The file's keys the fields would not write back: ones this build has no
  /// field for, and values it could not read. Export keeps them; see settings.md.
  var unrecognisedKeys: [String: JSONValue] = [:]

  public static let fileName = ".multishell.json"

  init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    defaultBranch: String? = nil,
    autoStartsAgent: Bool? = nil,
    autoStartsAgentOnCreate: Bool? = nil,
    opensTerminalOnSelect: Bool? = nil,
    opensTerminalOnCreate: Bool? = nil,
    preCreateHook: String? = nil,
    postCreateHook: String? = nil,
    preDeleteHook: String? = nil,
    postDeleteHook: String? = nil,
    linkedPaths: String? = nil,
    copiedPaths: String? = nil,
    worktreeSortOrder: WorktreeSortOrder? = nil,
    showsActiveWorktreesFirst: Bool? = nil,
    iconGlyph: String? = nil,
    iconTint: Int? = nil,
    digest: String? = nil
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
    self.defaultBranch = defaultBranch
    self.autoStartsAgent = autoStartsAgent
    self.autoStartsAgentOnCreate = autoStartsAgentOnCreate
    self.opensTerminalOnSelect = opensTerminalOnSelect
    self.opensTerminalOnCreate = opensTerminalOnCreate
    self.preCreateHook = Self.nonBlank(preCreateHook)
    self.postCreateHook = Self.nonBlank(postCreateHook)
    self.preDeleteHook = Self.nonBlank(preDeleteHook)
    self.postDeleteHook = Self.nonBlank(postDeleteHook)
    self.linkedPaths = Self.nonBlank(linkedPaths)
    self.copiedPaths = Self.nonBlank(copiedPaths)
    self.worktreeSortOrder = worktreeSortOrder
    self.showsActiveWorktreesFirst = showsActiveWorktreesFirst
    self.iconGlyph = Self.nonBlank(iconGlyph)
    self.iconTint = iconTint
    self.digest = digest
  }

  /// What a project's settings look like as a file, gaps left out. Export
  /// from the settings window.
  public init(exporting settings: ProjectSettings) {
    self.init(
      worktreeDirectory: settings.worktreeDirectory,
      branchPrefix: settings.branchPrefix,
      defaultBranch: settings.defaultBranch,
      autoStartsAgent: settings.autoStartsAgent,
      autoStartsAgentOnCreate: settings.autoStartsAgentOnCreate,
      opensTerminalOnSelect: settings.opensTerminalOnSelect,
      opensTerminalOnCreate: settings.opensTerminalOnCreate,
      preCreateHook: settings.preCreateHook,
      postCreateHook: settings.postCreateHook,
      preDeleteHook: settings.preDeleteHook,
      postDeleteHook: settings.postDeleteHook,
      linkedPaths: settings.linkedPaths,
      copiedPaths: settings.copiedPaths,
      worktreeSortOrder: settings.worktreeSortOrder,
      showsActiveWorktreesFirst: settings.showsActiveWorktreesFirst,
      iconGlyph: ProjectIcon.normalizedGlyph(settings.iconGlyph),
      iconTint: settings.iconTint)
  }

  /// Blank is absent where "none" and "no opinion" come to the same thing.
  /// The three worktree fields above are the exception; see settings.md.
  private static func nonBlank(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return value
  }
}
