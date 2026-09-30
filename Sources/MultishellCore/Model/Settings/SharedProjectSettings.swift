import Foundation

/// Settings a repository ships for everyone who adds it, read as defaults
/// under the user's own and trusted before running; see settings.md.
public struct SharedProjectSettings: Codable, Equatable, Sendable {
  /// Absent leaves the user's value standing; blank is an opinion, the only
  /// spelling these three have for "none". Every reader trims.
  public var worktreeDirectory: String?
  public var branchPrefix: String?
  public var defaultBranch: String?
  /// What a worktree here opens, and whether it runs the agent: a team may
  /// ship "a worktree comes up with an agent working in it".
  public var autoStartAgent: Bool?
  public var autoStartAgentOnCreate: Bool?
  public var opensTerminalOnSelect: Bool?
  public var opensTerminalOnCreate: Bool?
  public var preCreateHook: String?
  public var postCreateHook: String?
  public var preDeleteHook: String?
  public var postDeleteHook: String?
  /// Paths a new worktree is symlinked to, and paths copied. A repository may
  /// name only what is under it; `confined(to:)` drops the rest.
  public var linkedPaths: String?
  public var copiedPaths: String?
  /// What order a project's worktree rows come in. Display only, changing
  /// nothing the repository wrote on the reader's disk.
  public var worktreeSortOrder: WorktreeSortOrder?
  public var showsActiveWorktreesFirst: Bool?
  public var iconGlyph: String?
  public var iconTint: Int?

  /// The sha256 a hook trust decision is stored against; `nil` trusts nothing.
  /// Taken from the bytes by `load` and `fileContents`, as it decides whether hooks run.
  public internal(set) var digest: String?
  /// The file's keys the fields would not write back: ones this build has no
  /// field for, and values it could not read. Export keeps them; see settings.md.
  var unrecognisedKeys: [String: JSONValue] = [:]

  public static let fileName = ".multishell.json"

  init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    defaultBranch: String? = nil,
    autoStartAgent: Bool? = nil,
    autoStartAgentOnCreate: Bool? = nil,
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
    self.autoStartAgent = autoStartAgent
    self.autoStartAgentOnCreate = autoStartAgentOnCreate
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
      autoStartAgent: settings.autoStartAgent,
      autoStartAgentOnCreate: settings.autoStartAgentOnCreate,
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
