import Foundation

/// A file's relative image and sound paths made absolute, since libghostty reads
/// the merged text from the temp directory; see terminals/engine-and-config.md.
enum GhosttyConfigRelativePaths {
  /// The path-valued keys the allow list lets through.
  private static let pathKeys: Set<String> = ["background-image", "bell-audio-path"]

  static func resolved(in text: String, from directory: URL) -> String {
    GhosttyConfigLine.lines(of: text).map { line in
      let key = GhosttyConfigLine.key(of: line)
      guard pathKeys.contains(key), let value = GhosttyConfigPathValue(of: line), value.isRelative
      else { return String(line) }
      let path = directory.appendingPathComponent(value.path).path
      return "\(key) = \(value.isOptional ? "?" : "")\"\(path)\""
    }.joined(separator: "\n")
  }
}
