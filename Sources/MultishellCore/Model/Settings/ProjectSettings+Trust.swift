extension ProjectSettings {
  /// How many files a project remembers an answer for.
  static let rememberedDecisionLimit = 16

  /// Stores the answer for `digest`, replacing any earlier one about those
  /// bytes and moving it to the front, so the longest unasked-about falls off.
  public mutating func recordTrustDecision(digest: String, isTrusted: Bool) {
    trustDecisions.removeAll { $0.digest == digest }
    trustDecisions.insert(TrustDecision(digest: digest, isTrusted: isTrusted), at: 0)
    if trustDecisions.count > Self.rememberedDecisionLimit {
      trustDecisions.removeLast(
        trustDecisions.count - Self.rememberedDecisionLimit
      )
    }
  }

  /// Whether what `shared` asks for came from a file the user said yes to.
  /// Settings that came from no file trust nothing.
  public func trustsSharedSettings(of shared: SharedProjectSettings) -> Bool {
    trustDecision(about: shared) == true
  }

  /// `shared` as it applies here: what the yes covers dropped until it is given.
  public func sharedSettingsInForce(_ shared: SharedProjectSettings) -> SharedProjectSettings {
    trustsSharedSettings(of: shared) ? shared : shared.withoutWhatTrustCovers
  }

  /// The answer already given about `shared`, `nil` where none was. Export
  /// carries it onto the bytes it writes; see Docs/design/settings.md.
  public func trustDecision(about shared: SharedProjectSettings) -> Bool? {
    guard shared.asksForTrust, let digest = shared.digest else { return nil }
    return trustDecisions.first { $0.digest == digest }?.isTrusted
  }

  /// Whether `shared` asks for something in a file the user has not yet been
  /// asked about.
  public func needsTrustDecision(for shared: SharedProjectSettings) -> Bool {
    shared.asksForTrust && shared.digest != nil && trustDecision(about: shared) == nil
  }
}
