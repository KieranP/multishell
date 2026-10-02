extension SharedProjectSettings {
  /// The auto-start pair keeps the keys teams have already committed.
  enum CodingKeys: String, CodingKey {
    case worktreeDirectory, branchPrefix, defaultBranch
    case autoStartsAgent = "autoStartAgent"
    case autoStartsAgentOnCreate = "autoStartAgentOnCreate"
    case opensTerminalOnSelect, opensTerminalOnCreate, preCreateHook, postCreateHook, preDeleteHook,
      postDeleteHook, linkedPaths, copiedPaths, worktreeSortOrder, showsActiveWorktreesFirst,
      iconGlyph, iconTint
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // Tolerated throughout: a key of the wrong type costs that key, not
    // the file, which someone else on the team committed.
    func string(_ key: CodingKeys) -> String? {
      container.decodeTolerantly(String.self, forKey: key)
    }
    func bool(_ key: CodingKeys) -> Bool? {
      container.decodeTolerantly(Bool.self, forKey: key)
    }
    // An order a newer build named, or a typo someone committed, costs
    // the key and leaves the user's own choice in force.
    let sortOrder = container.decodeTolerantly(WorktreeSortOrder.self, forKey: .worktreeSortOrder)
    self.init(
      worktreeDirectory: string(.worktreeDirectory),
      branchPrefix: string(.branchPrefix),
      defaultBranch: string(.defaultBranch),
      autoStartsAgent: bool(.autoStartsAgent),
      autoStartsAgentOnCreate: bool(.autoStartsAgentOnCreate),
      opensTerminalOnSelect: bool(.opensTerminalOnSelect),
      opensTerminalOnCreate: bool(.opensTerminalOnCreate),
      preCreateHook: string(.preCreateHook),
      postCreateHook: string(.postCreateHook),
      preDeleteHook: string(.preDeleteHook),
      postDeleteHook: string(.postDeleteHook),
      linkedPaths: string(.linkedPaths),
      copiedPaths: string(.copiedPaths),
      worktreeSortOrder: sortOrder,
      showsActiveWorktreesFirst: bool(.showsActiveWorktreesFirst),
      iconGlyph: string(.iconGlyph),
      iconTint: container.decodeTolerantly(Int.self, forKey: .iconTint))
    let file = try decoder.container(keyedBy: RawCodingKey.self)
    let written = Set(try fields().keys)
    for key in file.allKeys where !written.contains(key.stringValue) {
      unrecognisedKeys[key.stringValue] = try file.decode(JSONValue.self, forKey: key)
    }
  }
}
