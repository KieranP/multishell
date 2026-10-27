import MultishellCore

/// What the tools were last adopted from, so finding the same again changes
/// nothing and redraws nothing.
struct ServiceToolAdoption: Equatable {
  let detection: ServiceToolDetection
  let searchPath: String?
  let loginVariables: [String: String]
  /// Without git none is connected, so git found later must connect them.
  let hasGit: Bool
}
