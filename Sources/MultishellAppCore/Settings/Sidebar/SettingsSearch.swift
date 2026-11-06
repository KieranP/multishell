import Foundation

/// The settings sidebar's search over each page's words: its title and the
/// labels of its rows, which the app passes in, being the app's to translate.
public enum SettingsSearch {
  /// Whether every word typed appears in one of `terms`, ignoring case and
  /// accents. Nothing typed matches every page.
  static func matches(_ query: String, terms: [String]) -> Bool {
    query.split(whereSeparator: \.isWhitespace).allSatisfy { word in
      terms.contains { $0.localizedStandardContains(word) }
    }
  }

  /// The sidebar's pages for `scope` that a query leaves listed, every one
  /// while nothing is typed, their words asked for only then.
  public static func pages(
    in scope: SettingsScope,
    matching query: String,
    terms: (SettingsPage) -> [String],
  ) -> [SettingsPage] {
    let pages = SettingsPage.pages(in: scope)
    guard !query.isEmpty else { return pages }
    return pages.filter { matches(query, terms: terms($0)) }
  }
}
