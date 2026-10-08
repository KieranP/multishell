/// The user's answer to "trust what this repository's `.multishell.json`
/// asks for?", against the sha256 of the file; see settings.md.
struct TrustDecision: Codable, Hashable, Sendable {
  /// `FileDigest.sha256` of the `.multishell.json` this answers for.
  var digest: String
  var isTrusted: Bool

  /// `isTrusted` keeps `trusted`, the key it was written under.
  private enum CodingKeys: String, CodingKey {
    case digest
    case isTrusted = "trusted"
  }
}
