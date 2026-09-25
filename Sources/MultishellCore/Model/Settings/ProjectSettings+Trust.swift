extension ProjectSettings {
  /// How many files a project remembers an answer for.
  static let rememberedDecisionLimit = 16

  /// Stores the answer for `digest`, replacing any earlier one about those
  /// bytes and moving it to the front, so the longest unasked-about falls off.
  public mutating func recordTrustDecision(digest: String, trusted: Bool) {
    sharedSettingsDecisions.removeAll { $0.digest == digest }
    sharedSettingsDecisions.insert(SharedSettingsDecision(digest: digest, trusted: trusted), at: 0)
    if sharedSettingsDecisions.count > Self.rememberedDecisionLimit {
      sharedSettingsDecisions.removeLast(
        sharedSettingsDecisions.count - Self.rememberedDecisionLimit)
    }
  }

  /// The answer stored about the file with digest `digest`, if the user has
  /// given one.
  func decision(aboutFile digest: String) -> SharedSettingsDecision? {
    sharedSettingsDecisions.first { $0.digest == digest }
  }

  /// Whether what `shared` asks for came from a file the user said yes to.
  /// Settings that came from no file trust nothing.
  public func trustsSharedSettings(of shared: SharedProjectSettings) -> Bool {
    guard shared.asksForTrust, let digest = shared.digest else { return false }
    return decision(aboutFile: digest)?.trusted == true
  }

  /// The answer already given about `shared`, `nil` where none was. Export
  /// carries it onto the bytes it writes; see Docs/design/settings.md.
  public func trustAnswer(about shared: SharedProjectSettings) -> Bool? {
    guard shared.asksForTrust, let digest = shared.digest else { return nil }
    return decision(aboutFile: digest)?.trusted
  }

  /// Whether `shared` asks for something in a file the user has not yet been
  /// asked about.
  public func needsTrustDecision(for shared: SharedProjectSettings) -> Bool {
    guard shared.asksForTrust, let digest = shared.digest else { return false }
    return decision(aboutFile: digest) == nil
  }
}
