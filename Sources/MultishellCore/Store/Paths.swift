import Foundation

/// Where Multishell keeps its state on each platform.
///
/// The only OS branch in the core. Linux follows the XDG spec; macOS has an
/// application-support directory Foundation already resolves
/// (`~/Library/Application Support`). Anything else that must differ per
/// platform belongs behind a port.
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

  /// Debug builds keep their own state, socket and integration files beside
  /// the release app's, so `make run` and the installed copy can run at once
  /// without the last autosave winning over the other's `state.json` or the
  /// two fighting for one socket. Themes and the helper link stay shared.
  ///
  /// A debug bundle built from a git worktree adds that worktree's name, for
  /// the same reason one level down: two worktrees can then both `make run`.
  /// The name rides in the bundle rather than the environment because `open`
  /// passes none to the app it launches. A build from the checkout carries
  /// no name and stays plain `.debug`, so an existing debug state file is
  /// still the one it reads.
  public static var variant: String {
    #if DEBUG
      debugVariant(named: bundledVariantName)
    #else
      ""
    #endif
  }

  /// Read through the enclosing `.app` rather than `Bundle.main` alone: the
  /// helper ships in `Contents/Helpers`, which CFBundle takes for the main
  /// bundle and which holds no `Info.plist`. Reading only `Bundle.main` would
  /// have the helper fall back to the plain socket while the app it ships
  /// inside listens on the named one. Held rather than recomputed because
  /// `variant` is read on every path and this walks to the root when there is
  /// no bundle at all, which is what a test binary looks like.
  private static let bundledVariantName: String? = {
    var directory = Bundle.main.bundleURL
    // Bounded on the component count rather than on the parent coming back
    // unchanged: at the root `deletingLastPathComponent` starts appending
    // `..` instead of standing still, so the obvious loop never ends and
    // every binary outside an `.app`, the test runner included, hangs.
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

  /// Split from `variant` so a test can name the value without a bundle.
  ///
  /// The name is cut to 16 characters and anything outside `[A-Za-z0-9_-]`
  /// replaced, because it lands in a socket path: `sun_path` holds 104 bytes
  /// and this directory plus `multishell.debug-.sock` already spends about
  /// 75 of them, so a long branch name would make the socket unbindable
  /// rather than merely ugly.
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

  /// Where generated shell-integration files live: this app points a zsh
  /// session's `ZDOTDIR` at `integration/zsh` and launches bash with
  /// `integration/bash/init.bash`, so the command-status hooks are in these
  /// terminals only and nothing is written to the user's own rc files.
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

  /// Where a drag's promised files are copied.
  ///
  /// A screenshot's preview hands its file over as a promise, and the copy
  /// macOS materialises for the app sits in a per-drag directory it opens to
  /// that app alone: the path pastes and the pane's own shell is refused it.
  /// So the copy is made here instead, where the shell and the agent at that
  /// prompt can read it and where the user can still find it afterwards.
  public static var dropsDirectory: URL {
    configDirectory.appendingPathComponent("drops\(variant)", isDirectory: true)
  }

  /// A stable path to the helper binary. It ships inside the bundle, and a
  /// hook holding the bundle's path breaks when the app moves; the app
  /// refreshes this link at every launch instead.
  public static var helperLink: URL {
    configDirectory.appendingPathComponent("bin", isDirectory: true)
      .appendingPathComponent("multishell", isDirectory: false)
  }
}
