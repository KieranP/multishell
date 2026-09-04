import Foundation

/// Finds a binary on `PATH`.
///
/// Hardcoding `/usr/bin/git` breaks on Windows and on distributions that ship
/// tools elsewhere, and `/usr/bin/env` is not a portable trampoline either.
public enum ExecutableLookup {
  public static func find(_ name: String) -> URL? {
    guard let path = ProcessInfo.processInfo.environment["PATH"] else { return nil }
    let fileName = platformName(name)
    for directory in path.split(separator: separator, omittingEmptySubsequences: true) {
      let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
        .appendingPathComponent(fileName)
      if FileManager.default.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
    }
    return nil
  }

  private static func platformName(_ name: String) -> String {
    #if os(Windows)
      return name.hasSuffix(".exe") ? name : name + ".exe"
    #else
      return name
    #endif
  }

  private static var separator: Character {
    #if os(Windows)
      return ";"
    #else
      return ":"
    #endif
  }
}
