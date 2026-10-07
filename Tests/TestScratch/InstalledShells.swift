import Foundation

/// The shells a test names, cut to those this machine has, so a missing one
/// drops its case rather than passing it.
public enum InstalledShells {
  public static let fishCandidates = ["/opt/homebrew/bin/fish", "/usr/local/bin/fish"]

  public static func only(_ paths: [String]) -> [String] {
    paths.filter(isInstalled)
  }

  public static func only<Case>(_ cases: [(String, Case)]) -> [(String, Case)] {
    cases.filter { isInstalled($0.0) }
  }

  public static func isInstalled(_ path: String) -> Bool {
    FileManager.default.isExecutableFile(atPath: path)
  }
}
