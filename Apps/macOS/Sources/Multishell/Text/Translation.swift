import Foundation
import MultishellCore

/// The words for `key` from the Mac app's own catalogue, one `t` per half and
/// no locale on the formatting; see docs/design/translation.md.
func t(_ key: String, _ arguments: any CVarArg...) -> String {
  let words = NSLocalizedString(key, bundle: .appCatalogue, comment: "")
  guard !arguments.isEmpty else { return words }
  return String(format: words, arguments: arguments)
}

extension Bundle {
  /// Where this app's catalogue is at runtime.
  static let appCatalogue = PackageBundle.holding(
    "Localizable", withExtension: "strings", named: "Multishell_Multishell.bundle", or: .module)
}
