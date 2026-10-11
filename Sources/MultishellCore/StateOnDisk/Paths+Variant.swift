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

  static let bundledVariantName: String? = {
    guard let executable = Bundle.main.executableURL,
      let name = variantName(ofBundleHolding: executable)
    else { return Bundle.main.object(forInfoDictionaryKey: variantKey) as? String }
    return name
  }()

  /// Through the enclosing `.app`: CFBundle takes `Contents/Helpers` for the
  /// main bundle, and `/usr/local/bin`'s link for one, so either reads another socket.
  static func variantName(ofBundleHolding executable: URL) -> String? {
    guard let app = executable.enclosingAppBundle else { return nil }
    let plist = app.appendingPathComponent("Contents/Info.plist", isDirectory: false)
    guard let data = try? Data(contentsOf: plist),
      let contents = try? PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any]
    else { return nil }
    return contents[variantKey] as? String
  }

  /// Split from `variant` so a test can name the value without a bundle. At
  /// most 14 of `[A-Za-z0-9_-]` for `sun_path` and its `.b`; see state-on-disk.md.
  static func debugVariant(named name: String?) -> String {
    guard let name, !name.isEmpty else { return ".debug" }
    guard name.count > 14 || !name.allSatisfy(\.isPortableNameCharacter) else {
      return ".debug-" + name
    }
    // A name cut or respelled keeps a hash of the whole, so two that start
    // alike still get files of their own.
    let start = name.prefix(9).map { $0.isPortableNameCharacter ? $0 : "-" }
    return ".debug-" + String(start) + "-" + String(format: "%04x", name.stableHash & 0xFFFF)
  }
}
