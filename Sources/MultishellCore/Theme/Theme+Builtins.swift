import Foundation

extension Theme {
  /// The base themes, then ports of popular editors' themes, each setting every
  /// key so none borrows Multishell's chrome; their licences are in Licenses/Themes/.
  public static let builtins: [Theme] =
    [.multishellDark, .multishellLight]
    + [
      "dracula", "one-dark", "nord", "solarized-light", "github-dark-default",
      "github-light-default", "catppuccin-mocha", "catppuccin-macchiato", "catppuccin-frappe",
      "catppuccin-latte",
    ].map(builtin(named:))

  /// The base themes: every key set, so each is what a user theme of its
  /// `is_dark` falls back on. Files rather than code so the examples are copies.
  static let multishellDark = builtin(named: "multishell.dark")
  static let multishellLight = builtin(named: "multishell.light")

  /// The file a built-in is read from, and its example copied from.
  static func builtinFile(named name: String) -> URL? {
    Bundle.coreResources.url(forResource: name, withExtension: "json", subdirectory: "themes")
  }

  /// A built-in that will not load is a broken build, which every test that
  /// reads a theme would show; see `ThemeBuiltinsTests`.
  private static func builtin(named name: String) -> Theme {
    guard
      let file = builtinFile(named: name),
      let data = try? Data(contentsOf: file),
      let theme = try? JSONDecoder().decode(Theme.self, from: data)
    else { preconditionFailure("the built-in theme \(name) did not load") }
    return theme
  }
}
