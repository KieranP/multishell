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

  public static var stateFile: URL {
    configDirectory.appendingPathComponent("state.json", isDirectory: false)
  }

  public static var themesDirectory: URL {
    configDirectory.appendingPathComponent("themes", isDirectory: true)
  }
}
