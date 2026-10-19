import Foundation

/// The grammars' highlights queries, read from their packages' resource bundles:
/// in the app's `Contents/Resources`, else beside the binary or test bundle.
enum GrammarQueries {
  /// The bundle holding this code is the app, or a test bundle, which lists
  /// in no `Bundle.allBundles` when swift-testing loads it.
  private static var containers: [URL] {
    let holdingThisCode = Bundle(for: SyntaxHighlighter.self).bundleURL
    return [Bundle.main.resourceURL, holdingThisCode.deletingLastPathComponent()].compactMap(\.self)
  }

  /// `nil` where no bundle holds the file.
  static func query(_ file: String, inBundle name: String) -> String? {
    for container in containers {
      let bundle = container.appending(path: "\(name).bundle", directoryHint: .isDirectory)
      for folder in ["Contents/Resources/queries", "queries"] {
        let url = bundle.appending(path: "\(folder)/\(file)")
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
      }
    }
    return nil
  }
}
