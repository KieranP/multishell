import Foundation

/// Where Multishell keeps its state on each platform.
///
/// The only OS branch in the core. Linux follows the XDG spec; macOS and
/// Windows both have an application-support directory Foundation already
/// resolves correctly (`~/Library/Application Support` and `%APPDATA%`).
/// Anything else that must differ per platform belongs behind a port.
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

  /// Debug builds keep their own state, socket and integration files beside
  /// the release app's, so `make run` and the installed copy can run at once
  /// without the last autosave winning over the other's `state.json` or the
  /// two fighting for one socket. Themes and the helper link stay shared.
  public static var variant: String {
    #if DEBUG
      ".debug"
    #else
      ""
    #endif
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

  /// A stable path to the helper binary. It ships inside the bundle, and a
  /// hook holding the bundle's path breaks when the app moves; the app
  /// refreshes this link at every launch instead.
  public static var helperLink: URL {
    configDirectory.appendingPathComponent("bin", isDirectory: true)
      .appendingPathComponent("multishell", isDirectory: false)
  }
}
