import Foundation

/// Settings a repository ships for everyone who adds it, read as defaults
/// under the user's own and trusted before running; see settings.md.
public struct SharedProjectSettings: Equatable, Sendable {
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
  /// Paths a new worktree is symlinked to, and paths copied. Both run
  /// nothing, so need no trust; `WorktreeFiles` refuses one reaching outside.
  public var linkedPaths: String?
  public var copiedPaths: String?
  /// What order a project's worktree rows come in. Display only, so like the
  /// settings above it runs nothing the repository wrote.
  public var worktreeSortOrder: WorktreeSortOrder?
  public var showsActiveWorktreesFirst: Bool?
  public var iconGlyph: String?
  public var iconTint: Int?

  /// The sha256 a hook trust decision is stored against; `nil` trusts
  /// nothing. Set only by `load` and `write`, since it decides whether hooks run.
  public private(set) var digest: String?

  public static let fileName = ".multishell.json"

  public init(
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
    self.preCreateHook = Self.text(preCreateHook)
    self.postCreateHook = Self.text(postCreateHook)
    self.preDeleteHook = Self.text(preDeleteHook)
    self.postDeleteHook = Self.text(postDeleteHook)
    self.linkedPaths = Self.text(linkedPaths)
    self.copiedPaths = Self.text(copiedPaths)
    self.worktreeSortOrder = worktreeSortOrder
    self.showsActiveWorktreesFirst = showsActiveWorktreesFirst
    self.iconGlyph = Self.text(iconGlyph)
    self.iconTint = iconTint
    self.digest = digest
  }

  /// Where the file lives for a repository at `repository`.
  public static func file(in repository: URL) -> URL {
    repository.appendingPathComponent(fileName, isDirectory: false)
  }

  /// The file's contents and the digest of its bytes, or `nil` when the
  /// repository has none. Throws for a file that is there but is not JSON.
  public static func load(from repository: URL) throws -> SharedProjectSettings? {
    let url = file(in: repository)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    var settings = try JSONDecoder().decode(SharedProjectSettings.self, from: data)
    settings.digest = FileDigest.sha256(of: data)
    return settings
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
      iconGlyph: ProjectIcon.symbolName(settings.iconGlyph),
      iconTint: settings.iconTint)
  }

  /// These settings with `existing`'s hooks where they have none. Export
  /// writes what is in force, and a hook the user refused is the file's word
  /// rather than theirs to drop; see docs/design/settings.md.
  public func keepingHooks(of existing: SharedProjectSettings?) -> SharedProjectSettings {
    guard let existing else { return self }
    var kept = self
    kept.preCreateHook = preCreateHook ?? existing.preCreateHook
    kept.postCreateHook = postCreateHook ?? existing.postCreateHook
    kept.preDeleteHook = preDeleteHook ?? existing.preDeleteHook
    kept.postDeleteHook = postDeleteHook ?? existing.postDeleteHook
    return kept
  }

  /// Writes the file, sorted and indented so a diff reads well. Returns it
  /// with the digest set, so the writer need not read the file back.
  @discardableResult public func write(to repository: URL) throws -> SharedProjectSettings {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    try data.write(to: Self.file(in: repository), options: .atomic)
    var written = self
    written.digest = FileDigest.sha256(of: data)
    return written
  }

  /// The four hooks as one text, what the trust question shows. For reading,
  /// not comparing: the decision is stored against `digest`.
  public var hooksText: String? {
    let hooks = [
      ("pre-create", preCreateHook), ("post-create", postCreateHook),
      ("pre-delete", preDeleteHook), ("post-delete", postDeleteHook),
    ]
    let present = hooks.compactMap { name, script in script.map { "\(name):\n\($0)" } }
    return present.isEmpty ? nil : present.joined(separator: "\n\n")
  }

  public var hasHooks: Bool { hooksText != nil }

  /// Blank is absent where "none" and "no opinion" come to the same thing.
  /// The three worktree fields above are the exception; see settings.md.
  private static func text(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    return value
  }
}

extension SharedProjectSettings: Codable {
  private enum CodingKeys: String, CodingKey {
    case worktreeDirectory, branchPrefix, defaultBranch, autoStartAgent, autoStartAgentOnCreate,
      opensTerminalOnSelect, opensTerminalOnCreate, preCreateHook, postCreateHook, preDeleteHook,
      postDeleteHook, linkedPaths, copiedPaths, worktreeSortOrder, showsActiveWorktreesFirst,
      iconGlyph, iconTint
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(worktreeDirectory, forKey: .worktreeDirectory)
    try container.encodeIfPresent(branchPrefix, forKey: .branchPrefix)
    try container.encodeIfPresent(defaultBranch, forKey: .defaultBranch)
    try container.encodeIfPresent(autoStartAgent, forKey: .autoStartAgent)
    try container.encodeIfPresent(autoStartAgentOnCreate, forKey: .autoStartAgentOnCreate)
    try container.encodeIfPresent(opensTerminalOnSelect, forKey: .opensTerminalOnSelect)
    try container.encodeIfPresent(opensTerminalOnCreate, forKey: .opensTerminalOnCreate)
    try container.encodeIfPresent(preCreateHook, forKey: .preCreateHook)
    try container.encodeIfPresent(postCreateHook, forKey: .postCreateHook)
    try container.encodeIfPresent(preDeleteHook, forKey: .preDeleteHook)
    try container.encodeIfPresent(postDeleteHook, forKey: .postDeleteHook)
    try container.encodeIfPresent(linkedPaths, forKey: .linkedPaths)
    try container.encodeIfPresent(copiedPaths, forKey: .copiedPaths)
    try container.encodeIfPresent(worktreeSortOrder, forKey: .worktreeSortOrder)
    try container.encodeIfPresent(showsActiveWorktreesFirst, forKey: .showsActiveWorktreesFirst)
    try container.encodeIfPresent(iconGlyph, forKey: .iconGlyph)
    try container.encodeIfPresent(iconTint, forKey: .iconTint)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Tolerated throughout: a key of the wrong type costs that key, not
    // the file, which someone else on the team committed.
    func string(_ key: CodingKeys) -> String? {
      container.decodeTolerantly(String.self, forKey: key)
    }
    func flag(_ key: CodingKeys) -> Bool? {
      container.decodeTolerantly(Bool.self, forKey: key)
    }
    self.init(
      worktreeDirectory: string(.worktreeDirectory),
      branchPrefix: string(.branchPrefix),
      defaultBranch: string(.defaultBranch),
      autoStartAgent: flag(.autoStartAgent),
      autoStartAgentOnCreate: flag(.autoStartAgentOnCreate),
      opensTerminalOnSelect: flag(.opensTerminalOnSelect),
      opensTerminalOnCreate: flag(.opensTerminalOnCreate),
      preCreateHook: string(.preCreateHook),
      postCreateHook: string(.postCreateHook),
      preDeleteHook: string(.preDeleteHook),
      postDeleteHook: string(.postDeleteHook),
      linkedPaths: string(.linkedPaths),
      copiedPaths: string(.copiedPaths),
      // An order a newer build named, or a typo someone committed, costs
      // the key and leaves the user's own choice in force.
      worktreeSortOrder: container.decodeTolerantly(
        WorktreeSortOrder.self, forKey: .worktreeSortOrder),
      showsActiveWorktreesFirst: flag(.showsActiveWorktreesFirst),
      iconGlyph: string(.iconGlyph),
      iconTint: container.decodeTolerantly(Int.self, forKey: .iconTint))
  }
}

/// The user's answer to "run the hooks in this repository's
/// `.multishell.json`?", against the sha256 of the file; see settings.md.
public struct SharedHooksDecision: Codable, Hashable, Sendable {
  /// `FileDigest.sha256` of the `.multishell.json` this answers for.
  public var digest: String
  public var trusted: Bool

  public init(digest: String, trusted: Bool) {
    self.digest = digest
    self.trusted = trusted
  }
}
