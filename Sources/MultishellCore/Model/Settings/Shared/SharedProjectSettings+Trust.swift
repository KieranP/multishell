extension SharedProjectSettings {
  /// What a yes covers, in the order the user is asked about them: every
  /// field that runs something or puts a path on disk.
  static let trustCoveredFields: [any WritableKeyPath<Self, String?> & Sendable] = [
    \.worktreeDirectory, \.preCreateHook, \.postCreateHook, \.preDeleteHook, \.postDeleteHook,
    \.linkedPaths, \.copiedPaths,
  ]

  /// What else a yes covers: each starts a program in the checkout, the agent with
  /// the reader's own flags. Only `true` asks, as turning one off runs nothing.
  static let trustCoveredStarts: [any WritableKeyPath<Self, Bool?> & Sendable] = [
    \.autoStartsAgent, \.autoStartsAgentOnCreate, \.opensTerminalOnSelect,
    \.opensTerminalOnCreate,
  ]

  /// The names the question gives `trustCoveredStarts`, in its order.
  private static var trustCoveredStartNames: [String] {
    [
      t("shared-settings.starts-agent"), t("shared-settings.starts-agent-on-create"),
      t("shared-settings.opens-terminal"), t("shared-settings.opens-terminal-on-create"),
    ]
  }

  /// The names the question gives `trustCoveredFields`, in its order.
  private static var trustCoveredNames: [String] {
    [
      t("shared-settings.worktree-directory"), t("shared-settings.pre-create"),
      t("shared-settings.post-create"), t("shared-settings.pre-delete"),
      t("shared-settings.post-delete"), t("shared-settings.linked"), t("shared-settings.copied"),
    ]
  }

  /// Everything the user is asked about, as one text. Trust is stored against
  /// `digest`, never this text; see Docs/design/settings.md.
  public var trustCoveredText: String? {
    var present = zip(Self.trustCoveredNames, Self.trustCoveredFields).compactMap { name, field in
      self[keyPath: field].map { "\(name):\n\($0)" }
    }
    let starts = zip(Self.trustCoveredStartNames, Self.trustCoveredStarts).compactMap { pair in
      self[keyPath: pair.1] == true ? pair.0 : nil
    }
    if !starts.isEmpty { present.append(starts.joined(separator: "\n")) }
    if let actions {
      let lines = actions.map { "\($0.name): \($0.command)" }
      present.append(([t("shared-settings.actions") + ":"] + lines).joined(separator: "\n"))
    }
    return present.isEmpty ? nil : present.joined(separator: "\n\n")
  }

  /// Whether the file asks for anything that reaches the reader's disk, and
  /// so waits for a yes. See Docs/design/settings.md.
  public var asksForTrust: Bool {
    Self.trustCoveredFields.contains { self[keyPath: $0] != nil }
      || Self.trustCoveredStarts.contains { self[keyPath: $0] == true }
      || actions != nil
  }

  /// The same file with everything the yes covers dropped: what an untrusted
  /// file is allowed to decide.
  var withoutWhatTrustCovers: SharedProjectSettings {
    var stripped = self
    for field in Self.trustCoveredFields { stripped[keyPath: field] = nil }
    for start in Self.trustCoveredStarts where self[keyPath: start] == true {
      stripped[keyPath: start] = nil
    }
    stripped.actions = nil
    return stripped
  }

  /// Whether every word a yes covers in `merged`, these carried over a file,
  /// is these settings' own, whatever order the merge puts their actions in.
  public func ownsEverythingTrustCovers(in merged: SharedProjectSettings) -> Bool {
    // An action entry this build cannot read is a teammate's word a newer build runs.
    let own = Set((try? Self.entries(of: actions)) ?? [])
    guard let entries = try? merged.mergedActionEntries(), entries.allSatisfy(own.contains)
    else { return false }
    var reordered = self
    let names = Set(actions?.map(\.name) ?? [])
    reordered.actions = merged.actions?.filter { names.contains($0.name) }
    return merged.trustCoveredText == reordered.trustCoveredText
  }
}
