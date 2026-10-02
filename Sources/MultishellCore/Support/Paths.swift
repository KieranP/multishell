import Foundation

/// Where Multishell keeps its state; see Docs/develop/state-on-disk.md.
public enum Paths {
  private static var stateDirectory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return base.appendingPathComponent("Multishell", isDirectory: true)
  }

  public static var stateFile: URL {
    stateDirectory.appendingPathComponent("state\(variant).json", isDirectory: false)
  }

  public static var themesDirectory: URL {
    stateDirectory.appendingPathComponent("themes", isDirectory: true)
  }

  /// Where the app listens for session-state reports. In the state
  /// directory, not `$TMPDIR`, so a hook can find it without being told.
  public static var socketFile: URL {
    stateDirectory.appendingPathComponent("multishell\(variant).sock", isDirectory: false)
  }

  /// Where generated shell-integration files live, so the command-status
  /// hooks reach these terminals only and never the user's own rc files.
  static var integrationDirectory: URL {
    stateDirectory.appendingPathComponent("integration\(variant)", isDirectory: true)
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
    stateDirectory.appendingPathComponent("drops\(variant)", isDirectory: true)
  }

  /// What every hook line and every file of ours names, and how one is told
  /// from a hook of the user's own.
  static let helperName = "multishell"

  /// A stable path to the helper binary, refreshed at every launch: a hook
  /// holding the bundle's own path breaks when the app moves.
  public static var helperLink: URL {
    stateDirectory.appendingPathComponent("bin", isDirectory: true)
      .appendingPathComponent(helperName, isDirectory: false)
  }
}
