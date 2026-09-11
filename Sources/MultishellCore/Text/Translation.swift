import Foundation

/// The words for `key` from the libraries' catalogue, one `t` per half and
/// no locale on the formatting; see docs/design/translation.md.
public func t(_ key: String, _ arguments: any CVarArg...) -> String {
  let words = NSLocalizedString(key, bundle: .catalogue, comment: "")
  guard !arguments.isEmpty else { return words }
  return String(format: words, arguments: arguments)
}

extension Bundle {
  /// Where the libraries' catalogue is at runtime.
  static let catalogue = PackageBundle.holding(
    "Localizable", withExtension: "strings", named: "multishell_MultishellCore.bundle",
    or: .module)
}
