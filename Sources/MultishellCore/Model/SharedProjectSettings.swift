import Foundation

/// Settings a repository ships for everyone who adds it: `.multishell.json`
/// at its root, with the same keys a project's settings have in
/// `state.json`. Read as defaults under the user's own, see
/// `ProjectSettings.layered`. Every field is optional and one that will not
/// decode costs that field only.
///
/// Hooks run code on the user's machine on the say of whoever committed the
/// file, so they take effect only once the user has trusted that exact
/// text; see `SharedHooksDecision`. Nothing else here runs anything the
/// repository wrote: what a worktree opens starts the shell or the agent
/// the user themselves chose, and only where they left the choice to the
/// global, and the file lists only link or duplicate files already in the
/// checkout.
public struct SharedProjectSettings: Equatable, Sendable {
  /// Absent means the file has no opinion and the user's own value stands.
  /// Blank is an opinion: the built-in directory, no prefix, or detect,
  /// whatever the reader's global says. It is the only spelling these three
  /// have for "none", the same as in `ProjectSettings`, and without it an
  /// export could not carry a project pinned that way. Every reader trims,
  /// so blank and whitespace say the same thing.
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
  /// Paths a new worktree is given a symlink to, one per line, and paths
  /// it is given a copy of. Both work inside the checkout the user already
  /// has and run nothing, so unlike the hooks above they need no trust;
  /// `WorktreeFiles` refuses a path that would reach outside the
  /// repository or the worktree.
  public var linkedPaths: String?
  public var copiedPaths: String?
  /// What order a project's worktree rows come in: a team may ship "our
  /// worktrees list by what was committed to last". Display only, so like
  /// the settings above and unlike the hooks it runs nothing the
  /// repository wrote.
  public var worktreeSortOrder: WorktreeSortOrder?
  public var showsActiveWorktreesFirst: Bool?
  public var iconGlyph: String?
  public var iconTint: Int?

  /// The sha256 of the file these were read from, `FileDigest`, which is
  /// what a hook trust decision is stored against: the answer is about the
  /// bytes on disk, and the state keeps a name for them rather than a copy
  /// of the scripts. `nil` for settings that came from no file, which
  /// trust nothing.
  ///
  /// Not a key of its own, and set only by `load` and `write`: it decides
  /// whether hooks run, so nothing outside this file may hand a value one
  /// and have it read as the file the user said yes to.
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
  /// repository has none. Throws for a file that is there but is not JSON,
  /// so the project can say so.
  public static func load(from repository: URL) throws -> SharedProjectSettings? {
    let url = file(in: repository)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let data = try Data(contentsOf: url)
    var settings = try JSONDecoder().decode(SharedProjectSettings.self, from: data)
    settings.digest = FileDigest.sha256(of: data)
    return settings
  }

  /// What a project's settings look like as a file: the overrides and hooks
  /// it has, the folder-following gaps left out. Export from the settings
  /// window.
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

  /// Writes the file for `repository`, sorted keys and indented so a diff
  /// of it reads well; absent fields are left out. Returns these settings
  /// as the file now holds them, digest and all, so the writer can trust
  /// what it wrote without reading the file back.
  @discardableResult public func write(to repository: URL) throws -> SharedProjectSettings {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(self)
    try data.write(to: Self.file(in: repository), options: .atomic)
    var written = self
    written.digest = FileDigest.sha256(of: data)
    return written
  }

  /// The four hooks as one text, what the trust question shows; `nil` when
  /// the file has none. The decision itself is stored against `digest`, so
  /// this is for reading and not for comparing.
  public var hooksText: String? {
    let hooks = [
      ("pre-create", preCreateHook), ("post-create", postCreateHook),
      ("pre-delete", preDeleteHook), ("post-delete", postDeleteHook),
    ]
    let present = hooks.compactMap { name, script in script.map { "\(name):\n\($0)" } }
    return present.isEmpty ? nil : present.joined(separator: "\n\n")
  }

  public var hasHooks: Bool { hooksText != nil }

  /// Blank is the same as absent for a field where "none" and "no opinion"
  /// come to the same thing: an empty hook is not a hook to be trusted, an
  /// empty file list links nothing, and a blank glyph draws the folder `nil`
  /// draws. The three worktree fields above are the exception and keep
  /// theirs, blank being the only way they say "none".
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
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(worktreeDirectory, forKey: .worktreeDirectory)
    try c.encodeIfPresent(branchPrefix, forKey: .branchPrefix)
    try c.encodeIfPresent(defaultBranch, forKey: .defaultBranch)
    try c.encodeIfPresent(autoStartAgent, forKey: .autoStartAgent)
    try c.encodeIfPresent(autoStartAgentOnCreate, forKey: .autoStartAgentOnCreate)
    try c.encodeIfPresent(opensTerminalOnSelect, forKey: .opensTerminalOnSelect)
    try c.encodeIfPresent(opensTerminalOnCreate, forKey: .opensTerminalOnCreate)
    try c.encodeIfPresent(preCreateHook, forKey: .preCreateHook)
    try c.encodeIfPresent(postCreateHook, forKey: .postCreateHook)
    try c.encodeIfPresent(preDeleteHook, forKey: .preDeleteHook)
    try c.encodeIfPresent(postDeleteHook, forKey: .postDeleteHook)
    try c.encodeIfPresent(linkedPaths, forKey: .linkedPaths)
    try c.encodeIfPresent(copiedPaths, forKey: .copiedPaths)
    try c.encodeIfPresent(worktreeSortOrder, forKey: .worktreeSortOrder)
    try c.encodeIfPresent(showsActiveWorktreesFirst, forKey: .showsActiveWorktreesFirst)
    try c.encodeIfPresent(iconGlyph, forKey: .iconGlyph)
    try c.encodeIfPresent(iconTint, forKey: .iconTint)
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    func string(_ key: CodingKeys) -> String? {
      (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil
    }
    // Same as `string`: a key of the wrong type costs that key, not the file.
    func flag(_ key: CodingKeys) -> Bool? {
      (try? c.decodeIfPresent(Bool.self, forKey: key)) ?? nil
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
      worktreeSortOrder: (try? c.decodeIfPresent(
        WorktreeSortOrder.self, forKey: .worktreeSortOrder)) ?? nil,
      showsActiveWorktreesFirst: flag(.showsActiveWorktreesFirst),
      iconGlyph: string(.iconGlyph),
      iconTint: (try? c.decodeIfPresent(Int.self, forKey: .iconTint)) ?? nil)
  }
}

/// The user's answer to "run the hooks in this repository's
/// `.multishell.json`?", against the sha256 of the file it was about.
/// Stored on the project, one per file in `ProjectSettings.sharedHooks`, so
/// a file is asked about once and not once per launch or per switch back to
/// the branch that carries it.
///
/// The digest and not the hook text: the state keeps a fixed-length name
/// for the file rather than copies of everyone's scripts, and a yes is
/// about the bytes that were on disk when it was given.
public struct SharedHooksDecision: Codable, Hashable, Sendable {
  /// `FileDigest.sha256` of the `.multishell.json` this answers for.
  public var digest: String
  public var trusted: Bool

  public init(digest: String, trusted: Bool) {
    self.digest = digest
    self.trusted = trusted
  }
}
