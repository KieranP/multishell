import Foundation

/// Per-project preferences, edited in the project's settings panel.
///
/// The worktree fields are overrides: `nil` means "use the app-wide value in
/// `Workspace.worktreeDefaults`". Hooks are per-project only.
public struct ProjectSettings: Codable, Hashable, Sendable {
  public var worktreeDirectory: String?
  public var branchPrefix: String?
  /// The branch this project's work is merged into, for the sidebar's
  /// merged badge. `nil` detects it: `origin/HEAD`, then `origin/main`,
  /// `origin/master`, `main`, `master`. A name typed here is looked for on
  /// `origin` before it is looked for locally.
  public var defaultBranch: String?

  /// Scripts run through the user's login shell around `git worktree add`
  /// and `git worktree remove`. Empty means no hook. A pre hook that fails
  /// stops the operation; a post hook that fails is reported after it.
  public var preCreateHook: String
  public var postCreateHook: String
  public var preDeleteHook: String
  public var postDeleteHook: String

  /// Files and folders each new worktree is given a symlink to, pointing
  /// back at the repository's own, one path per line, for what a worktree
  /// can share rather than hold twice: `node_modules`, a build cache.
  /// Blank means nothing is linked.
  public var linkedPaths: String
  /// Files and folders copied from the repository into each new worktree,
  /// one path per line, for what git does not carry and a worktree wants
  /// its own of: `.env`, a local config. Blank means nothing is copied.
  public var copiedPaths: String

  /// Agent override by catalogue id. `nil` follows the global choice;
  /// `AgentCatalogue.noneID` opts this project out of it.
  public var preferredAgentID: String?
  /// Whether new tabs here start the agent. `nil` follows the global.
  public var autoStartAgent: Bool?
  /// Whether the tab a worktree created here opens starts the agent. `nil`
  /// follows the global.
  public var autoStartAgentOnCreate: Bool?

  /// Whether a worktree here opens a terminal when it is turned to. `nil`
  /// follows the global.
  public var opensTerminalOnSelect: Bool?

  /// The order this project's worktree rows are listed in. `nil` follows
  /// the global.
  public var worktreeSortOrder: WorktreeSortOrder?
  /// Whether this project's busy worktrees are listed above the rest.
  /// `nil` follows the global.
  public var showsActiveWorktreesFirst: Bool?

  /// Whether a worktree created here opens a terminal once the create, and
  /// any post-create hook, is done. `nil` follows the global.
  public var opensTerminalOnCreate: Bool?

  /// Shell override by path. `nil` follows the global choice;
  /// `ShellCatalogue.loginShellID` means `$SHELL` here whatever it says.
  public var defaultShell: String?

  /// The sidebar glyph: an emoji, or an SF Symbol name from
  /// `ProjectIcon.symbols`. `nil` draws the folder.
  public var iconGlyph: String?
  /// A slot in the theme's sixteen ANSI colours, or `nil` for the chrome's
  /// own text colour. Applies to symbols and the folder; emoji keep their
  /// own colours.
  public var iconTint: Int?

  /// What the user said about the hooks in the repository's
  /// `.multishell.json`, one answer per file they were asked about, held
  /// against the sha256 of its bytes, the most recent first. Empty until
  /// asked; a file with no answer here asks.
  ///
  /// A list rather than the one last answer, because the file is tracked
  /// and so differs between branches: two branches shipping different
  /// hooks asked again on every switch between them, and each answer
  /// forgot the other. The oldest is dropped past
  /// `rememberedSharedHooks`, so a file edited on a loop cannot grow the
  /// state without bound.
  public var sharedHooks: [SharedHooksDecision]

  /// How many files a project remembers an answer for: enough for the
  /// branches someone moves between, and for a file edited a few times.
  public static let rememberedSharedHooks = 16

  public init(
    worktreeDirectory: String? = nil,
    branchPrefix: String? = nil,
    defaultBranch: String? = nil,
    preCreateHook: String = "",
    postCreateHook: String = "",
    preDeleteHook: String = "",
    postDeleteHook: String = "",
    linkedPaths: String = "",
    copiedPaths: String = "",
    preferredAgentID: String? = nil,
    autoStartAgent: Bool? = nil,
    autoStartAgentOnCreate: Bool? = nil,
    opensTerminalOnSelect: Bool? = nil,
    opensTerminalOnCreate: Bool? = nil,
    worktreeSortOrder: WorktreeSortOrder? = nil,
    showsActiveWorktreesFirst: Bool? = nil,
    defaultShell: String? = nil,
    iconGlyph: String? = nil,
    iconTint: Int? = nil,
    sharedHooks: [SharedHooksDecision] = []
  ) {
    self.worktreeDirectory = worktreeDirectory
    self.branchPrefix = branchPrefix
    self.defaultBranch = defaultBranch
    self.preCreateHook = preCreateHook
    self.postCreateHook = postCreateHook
    self.preDeleteHook = preDeleteHook
    self.postDeleteHook = postDeleteHook
    self.linkedPaths = linkedPaths
    self.copiedPaths = copiedPaths
    self.preferredAgentID = preferredAgentID
    self.autoStartAgent = autoStartAgent
    self.autoStartAgentOnCreate = autoStartAgentOnCreate
    self.opensTerminalOnSelect = opensTerminalOnSelect
    self.opensTerminalOnCreate = opensTerminalOnCreate
    self.worktreeSortOrder = worktreeSortOrder
    self.showsActiveWorktreesFirst = showsActiveWorktreesFirst
    self.defaultShell = defaultShell
    self.iconGlyph = iconGlyph
    self.iconTint = ProjectIcon.validTint(iconTint)
    self.sharedHooks = sharedHooks
  }

  /// An empty string is the override to "none" for the three worktree
  /// fields, and noise for a field that spells its own "none" some other
  /// way.
  ///
  /// The worktree fields have no other spelling for it: blank is how a
  /// project pins itself to the built-in directory, to no prefix while the
  /// global has one, or to detecting its default branch while the
  /// repository's file names one. Coercing those to `nil` sent them back to
  /// following the global on the next load, losing the very thing the
  /// settings form's help offers. `preferredAgentID` and `defaultShell`
  /// have `AgentCatalogue.noneID` and `ShellCatalogue.loginShellID` for it,
  /// and a blank `iconGlyph` draws the same folder `nil` does, so `""`
  /// there says nothing an absent key does not.
  ///
  /// `SharedProjectSettings` deliberately does the opposite for these same
  /// three, and says why: a `""` someone committed must not read as the team
  /// asking for "none". A choice the user made in the form and a stray key
  /// in a tracked file are not the same claim. The cost is that an export
  /// cannot carry a blank override, and drops it back to following the
  /// global for whoever reads the file.
  ///
  /// State from before this repository's first commit stored `""` for "no
  /// prefix"; that loads as the override now. For the prefix it is the
  /// behaviour those projects already had. For `worktreeDirectory` it is
  /// not quite: blank resolves to the built-in `../{project}-worktrees`
  /// rather than to a global the user has since set.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    worktreeDirectory = try c.decodeIfPresent(String.self, forKey: .worktreeDirectory)
    branchPrefix = try c.decodeIfPresent(String.self, forKey: .branchPrefix)
    defaultBranch = try c.decodeIfPresent(String.self, forKey: .defaultBranch)
    preCreateHook = try c.decodeIfPresent(String.self, forKey: .preCreateHook) ?? ""
    postCreateHook = try c.decodeIfPresent(String.self, forKey: .postCreateHook) ?? ""
    preDeleteHook = try c.decodeIfPresent(String.self, forKey: .preDeleteHook) ?? ""
    postDeleteHook = try c.decodeIfPresent(String.self, forKey: .postDeleteHook) ?? ""
    linkedPaths = try c.decodeIfPresent(String.self, forKey: .linkedPaths) ?? ""
    copiedPaths = try c.decodeIfPresent(String.self, forKey: .copiedPaths) ?? ""
    preferredAgentID = Self.override(try c.decodeIfPresent(String.self, forKey: .preferredAgentID))
    autoStartAgent = try c.decodeIfPresent(Bool.self, forKey: .autoStartAgent)
    // Absent is "follow the global", not "what `autoStartAgent` says": a
    // nil override is written as an absent key, so seeding it from the
    // other one would turn the global back into an override on every load.
    autoStartAgentOnCreate = try c.decodeIfPresent(Bool.self, forKey: .autoStartAgentOnCreate)
    opensTerminalOnSelect = try c.decodeIfPresent(Bool.self, forKey: .opensTerminalOnSelect)
    opensTerminalOnCreate = try c.decodeIfPresent(Bool.self, forKey: .opensTerminalOnCreate)
    // `try?`: an order a newer build named is not an override this one can
    // honour, and following the global beats losing the project.
    worktreeSortOrder =
      (try? c.decodeIfPresent(WorktreeSortOrder.self, forKey: .worktreeSortOrder)) ?? nil
    showsActiveWorktreesFirst = try c.decodeIfPresent(
      Bool.self, forKey: .showsActiveWorktreesFirst)
    defaultShell = Self.override(try c.decodeIfPresent(String.self, forKey: .defaultShell))
    iconGlyph = Self.override(try c.decodeIfPresent(String.self, forKey: .iconGlyph))
    // `try?`: a tint that is not a number costs the tint, not the file.
    iconTint = ProjectIcon.validTint(try? c.decodeIfPresent(Int.self, forKey: .iconTint))
    // Lossy: an answer that will not decode costs that answer and not the
    // project's others, and its hooks are asked about again. What builds
    // before the digest wrote is a whole such value, one decision holding
    // the hook text it was answered about, which no digest can be had
    // from; it reads as no answers, and asks once more.
    sharedHooks = c.decodeLossy(SharedHooksDecision.self, forKey: .sharedHooks)
  }

  private static func override(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }

  /// Stores the answer for the file with digest `digest`, replacing any
  /// earlier answer about those same bytes and moving it to the front, so
  /// what falls off the end is the file longest unanswered-about.
  public mutating func recordSharedHooks(file digest: String, trusted: Bool) {
    sharedHooks.removeAll { $0.digest == digest }
    sharedHooks.insert(SharedHooksDecision(digest: digest, trusted: trusted), at: 0)
    if sharedHooks.count > Self.rememberedSharedHooks {
      sharedHooks.removeLast(sharedHooks.count - Self.rememberedSharedHooks)
    }
  }

  /// The answer stored about the file with digest `digest`, if the user has
  /// given one.
  func decision(aboutFile digest: String) -> SharedHooksDecision? {
    sharedHooks.first { $0.digest == digest }
  }

  /// Whether the hooks in `shared` are hooks the user trusted: the file it
  /// was read from is one they said yes to. A file edited to bytes nobody
  /// answered about is not trusted until asked; one changed back to bytes
  /// they trusted is. Settings that came from no file trust nothing.
  public func trustsHooks(of shared: SharedProjectSettings) -> Bool {
    guard shared.hasHooks, let digest = shared.digest else { return false }
    return decision(aboutFile: digest)?.trusted == true
  }

  /// Whether `shared` has hooks in a file the user has not yet been asked
  /// about.
  public func needsHookDecision(for shared: SharedProjectSettings) -> Bool {
    guard shared.hasHooks, let digest = shared.digest else { return false }
    return decision(aboutFile: digest) == nil
  }

  /// These settings with the repository's own filling the gaps: a path or
  /// prefix the user left following the global, what a worktree here opens
  /// where they said nothing, the order its rows come in, an icon they did
  /// not set, the files a new worktree is linked to or given, and a hook
  /// they left blank, the last only once its file is trusted. A
  /// whitespace-only hook, or file list, is the user's "none" and stays.
  public func layered(over shared: SharedProjectSettings?) -> ProjectSettings {
    guard let shared else { return self }
    var result = self
    result.worktreeDirectory = worktreeDirectory ?? shared.worktreeDirectory
    result.branchPrefix = branchPrefix ?? shared.branchPrefix
    result.defaultBranch = defaultBranch ?? shared.defaultBranch
    result.autoStartAgent = autoStartAgent ?? shared.autoStartAgent
    result.autoStartAgentOnCreate = autoStartAgentOnCreate ?? shared.autoStartAgentOnCreate
    result.opensTerminalOnSelect = opensTerminalOnSelect ?? shared.opensTerminalOnSelect
    result.opensTerminalOnCreate = opensTerminalOnCreate ?? shared.opensTerminalOnCreate
    result.worktreeSortOrder = worktreeSortOrder ?? shared.worktreeSortOrder
    result.showsActiveWorktreesFirst =
      showsActiveWorktreesFirst ?? shared.showsActiveWorktreesFirst
    result.iconGlyph = iconGlyph ?? shared.iconGlyph
    result.iconTint = iconTint ?? ProjectIcon.validTint(shared.iconTint)
    result.linkedPaths = linkedPaths.isEmpty ? shared.linkedPaths ?? "" : linkedPaths
    result.copiedPaths = copiedPaths.isEmpty ? shared.copiedPaths ?? "" : copiedPaths
    if trustsHooks(of: shared) {
      result.preCreateHook = preCreateHook.isEmpty ? shared.preCreateHook ?? "" : preCreateHook
      result.postCreateHook = postCreateHook.isEmpty ? shared.postCreateHook ?? "" : postCreateHook
      result.preDeleteHook = preDeleteHook.isEmpty ? shared.preDeleteHook ?? "" : preDeleteHook
      result.postDeleteHook = postDeleteHook.isEmpty ? shared.postDeleteHook ?? "" : postDeleteHook
    }
    return result
  }

  /// The project's value where it has one, the default otherwise.
  public func effective(defaults: WorktreeSettings) -> WorktreeSettings {
    WorktreeSettings(
      worktreeDirectory: worktreeDirectory?.trimmingCharacters(in: .whitespaces)
        ?? defaults.worktreeDirectory,
      branchPrefix: branchPrefix?.trimmingCharacters(in: .whitespaces) ?? defaults.branchPrefix
    )
  }
}
