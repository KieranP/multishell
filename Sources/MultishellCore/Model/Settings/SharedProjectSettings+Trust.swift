extension SharedProjectSettings {
  /// Everything the user is asked about, as one text. Trust is stored against
  /// `digest`, never this text; see Docs/design/settings.md.
  public var trustCoveredText: String? {
    let present = zip(Self.trustCoveredNames, Self.trustCovered).compactMap { name, field in
      self[keyPath: field].map { "\(name):\n\($0)" }
    }
    return present.isEmpty ? nil : present.joined(separator: "\n\n")
  }

  /// Whether the file asks for anything that reaches the reader's disk, and
  /// so waits for a yes. See Docs/design/settings.md.
  public var asksForTrust: Bool {
    Self.trustCovered.contains { self[keyPath: $0] != nil }
  }

  /// The same file with everything the yes covers dropped: what an untrusted
  /// file is allowed to decide.
  var withoutWhatTrustCovers: SharedProjectSettings {
    var stripped = self
    for field in Self.trustCovered { stripped[keyPath: field] = nil }
    return stripped
  }

  /// What a yes covers, in the order the user is asked about them: every
  /// field that runs something or puts a path on disk.
  static let trustCovered: [WritableKeyPath<Self, String?> & Sendable] = [
    \.worktreeDirectory, \.preCreateHook, \.postCreateHook, \.preDeleteHook, \.postDeleteHook,
    \.linkedPaths, \.copiedPaths,
  ]

  /// The names the question gives `trustCovered`, in its order.
  private static var trustCoveredNames: [String] {
    [
      t("shared-settings.worktree-directory"), t("shared-settings.pre-create"),
      t("shared-settings.post-create"), t("shared-settings.pre-delete"),
      t("shared-settings.post-delete"), t("shared-settings.linked"), t("shared-settings.copied"),
    ]
  }
}
