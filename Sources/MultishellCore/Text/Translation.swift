import Foundation

/// The words for `key`, in the language the user reads. This is the
/// libraries' catalogue,
/// `Sources/MultishellCore/Resources/en.lproj/Localizable.strings`.
///
/// There is one of these per half, each reading its own catalogue: a
/// function declared in a module beats the same one imported, so a
/// `t(_:_:)` written in a library file reaches the libraries' words and one
/// written in a view reaches the Mac app's, neither having to say which.
/// App code never reads the libraries' catalogue; a word both halves say is
/// written in both, so a frontend can word its own chrome without touching
/// what the model says. Only a module importing both sees two, and names
/// the one it means.
///
/// A translation is that folder again under another language code, plus a
/// line in the manifest. `arguments` fill in a `%@` or a `%d`, and a phrase
/// whose wording turns on a number has its rule in
/// `Localizable.stringsdict` under the same key and takes the number here
/// like any other argument.
///
/// A key with no entry answers with itself rather than blank, and
/// TranslationTests fails on it: nothing can reach a screen as its own key
/// without the suite saying so.
///
/// No locale on the formatting, so a number is written the way Swift writes
/// one: the app's numbers are counts and seconds, and a locale here would
/// put a comma in the one decimal the board shows and make every test of it
/// read the machine's region. Which plural form is chosen is the
/// catalogue's and is not affected.
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
