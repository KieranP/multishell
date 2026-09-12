import Foundation

extension StringProtocol {
  /// Contains `needle`, ignoring case and accents, by Unicode's own rules
  /// rather than the reader's alphabet; see docs/design/translation.md.
  public func foldedContains(_ needle: some StringProtocol) -> Bool {
    guard !needle.isEmpty else { return true }
    return range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], locale: nil) != nil
  }
}
