import Foundation

/// Where Multishell keeps its state on each platform, and the only OS branch
/// in the core; see docs/develop/state-on-disk.md.
public enum Paths {
  public static var configDirectory: URL {
    #if os(Linux)
      let environment = ProcessInfo.processInfo.environment
      let base =
        environment["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config", isDirectory: true)
      return base.appendingPathComponent("multishell", isDirectory: true)
    #else
      let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      return base.appendingPathComponent("Multishell", isDirectory: true)
    #endif
  }

  /// The `Info.plist` key naming the worktree a debug bundle was built from.
  /// `Scripts/make-app.sh` writes it; nothing at build time joins the two.
  public static let variantKey = "MultishellVariant"

  /// Debug builds keep their own files, a worktree build naming itself; see
  /// docs/develop/state-on-disk.md. The name rides in the bundle.
  public static var variant: String {
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
  /// to 16 of `[A-Za-z0-9_-]` for `sun_path`; see state-on-disk.md.
  static func debugVariant(named name: String?) -> String {
    guard let name, !name.isEmpty else { return ".debug" }
    let safe = name.prefix(16).map { character -> Character in
      character.isASCII && (character.isLetter || character.isNumber)
        || character == "-" || character == "_" ? character : "-"
    }
    return ".debug-" + String(safe)
  }

  public static var stateFile: URL {
    configDirectory.appendingPathComponent("state\(variant).json", isDirectory: false)
  }

  public static var themesDirectory: URL {
    configDirectory.appendingPathComponent("themes", isDirectory: true)
  }

  /// Where the app listens for session-state reports. In the state
  /// directory, not `$TMPDIR`, so a hook can find it without being told.
  public static var socketFile: URL {
    configDirectory.appendingPathComponent("multishell\(variant).sock", isDirectory: false)
  }

  /// Where generated shell-integration files live, so the command-status
  /// hooks reach these terminals only and never the user's own rc files.
  public static var integrationDirectory: URL {
    configDirectory.appendingPathComponent("integration\(variant)", isDirectory: true)
  }

  public static var zshIntegrationDirectory: URL {
    integrationDirectory.appendingPathComponent("zsh", isDirectory: true)
  }

  public static var bashInitFile: URL {
    integrationDirectory.appendingPathComponent("bash", isDirectory: true)
      .appendingPathComponent("init.bash", isDirectory: false)
  }

  /// Where a drag's promised files are copied. macOS materialises one into a
  /// per-drag directory the pane's own shell is refused; see terminals.md.
  public static var dropsDirectory: URL {
    configDirectory.appendingPathComponent("drops\(variant)", isDirectory: true)
  }

  /// A stable path to the helper binary, refreshed at every launch: a hook
  /// holding the bundle's own path breaks when the app moves.
  public static var helperLink: URL {
    configDirectory.appendingPathComponent("bin", isDirectory: true)
      .appendingPathComponent("multishell", isDirectory: false)
  }
}
