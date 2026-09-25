import Foundation

/// The words for `key` from the libraries' catalogue, one `t` per half and
/// no locale on the formatting; see Docs/design/translation.md.
public func t(_ key: String, _ arguments: any CVarArg...) -> String {
  let words = NSLocalizedString(key, bundle: .coreResources, comment: "")
  guard !arguments.isEmpty else { return words }
  return String(format: words, arguments: arguments)
}
