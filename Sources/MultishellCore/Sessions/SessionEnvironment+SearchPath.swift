import Foundation

extension SessionEnvironment {
  /// Ours lead: on a case-insensitive disk `multishell` in an app's own directory
  /// is that app, and another build's inherited one would answer; terminals.md.
  static func searchPath(_ inherited: String?, leadingWith bundle: BundleDirectories) -> String {
    let ours = leadingEntries(of: bundle)
    let theirs = (inherited ?? "").split(separator: ":").map(String.init).filter { entry in
      !ours.contains(entry)
    }
    return (ours + theirs).joined(separator: ":")
  }

  static func leadingEntries(of bundle: BundleDirectories) -> [String] {
    [bundle.helper.path, bundle.app.path]
  }
}
