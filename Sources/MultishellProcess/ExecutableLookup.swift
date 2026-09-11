import Foundation

/// Finds a binary on `PATH`: hardcoding `/usr/bin/git` breaks where tools
/// ship elsewhere, and `/usr/bin/env` is no portable trampoline.
public enum ExecutableLookup {
  /// On the process's own PATH, which from the Finder is the system
  /// directories only. Pass the login shell's to find what a terminal would.
  public static func find(_ name: String, path: String? = nil) -> URL? {
    guard let path = path ?? ProcessInfo.processInfo.environment["PATH"] else { return nil }
    for directory in path.split(separator: ":", omittingEmptySubsequences: true) {
      let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
        .appendingPathComponent(name)
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }
}
