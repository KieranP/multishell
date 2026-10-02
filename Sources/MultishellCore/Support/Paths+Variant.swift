import Foundation

extension Paths {
  /// The `Info.plist` key naming the worktree a debug bundle was built from.
  /// `Scripts/make-app.sh` writes it; nothing at build time joins the two.
  static let variantKey = "MultishellVariant"

  /// Debug builds keep their own files, a worktree build naming itself; see
  /// Docs/develop/state-on-disk.md. The name rides in the bundle.
  static var variant: String {
    #if DEBUG
      debugVariant(named: bundledVariantName)
    #else
      ""
    #endif
  }

  /// Through the enclosing `.app`: CFBundle takes `Contents/Helpers` for the
  /// main bundle, so the helper would read the wrong socket.
  private static let bundledVariantName: String? = {
    var directory = Bundle.main.bundleURL
    // Bounded on component count: at the root `deletingLastPathComponent`
    // appends `..` rather than standing still, so the obvious loop hangs.
    while directory.pathComponents.count > 1 {
      if directory.pathExtension == "app" {
        let plist = directory.appendingPathComponent("Contents/Info.plist", isDirectory: false)
        guard let data = try? Data(contentsOf: plist),
          let contents = try? PropertyListSerialization.propertyList(from: data, format: nil)
            as? [String: Any]
        else { return nil }
        return contents[variantKey] as? String
      }
      directory = directory.deletingLastPathComponent()
    }
    return Bundle.main.object(forInfoDictionaryKey: variantKey) as? String
  }()

  /// Split from `variant` so a test can name the value without a bundle. Cut
  /// to 14 of `[A-Za-z0-9_-]` for `sun_path` and its `.b`; see state-on-disk.md.
  static func debugVariant(named name: String?) -> String {
    guard let name, !name.isEmpty else { return ".debug" }
    let safe = name.prefix(14).map { character -> Character in
      character.isASCII && (character.isLetter || character.isNumber)
        || character == "-" || character == "_" ? character : "-"
    }
    return ".debug-" + String(safe)
  }
}
