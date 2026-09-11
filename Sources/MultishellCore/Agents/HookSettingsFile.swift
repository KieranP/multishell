import Foundation

/// Reading and rewriting a JSON file an agent keeps its settings in. The
/// file is the user's: anything not plain JSON is refused; see agents.md.
public enum HookSettingsFile {
  /// An empty object for a missing or blank file; anything else it cannot
  /// read back is an error, rewriting having to destroy what it missed.
  public static func read(_ file: URL) throws -> [String: Any] {
    guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
    let data = try Data(contentsOf: file)
    guard data.contains(where: { !" \t\r\n".utf8.contains($0) }) else { return [:] }
    guard let object = try? JSONSerialization.jsonObject(with: data) else {
      throw UnparsableSettingsFile(file: file)
    }
    guard let settings = object as? [String: Any] else {
      throw UnexpectedSettingsShape(file: file)
    }
    return settings
  }

  public static func write(_ settings: [String: Any], to file: URL) throws {
    try backUp(file)
    try writeOurs(render(settings), to: file)
  }

  /// Where a write lands. A link at the end of the path is written through,
  /// not over, so a dotfiles repo keeps seeing the file; see agents.md.
  static func destination(of file: URL) -> URL {
    guard (try? FileManager.default.destinationOfSymbolicLink(atPath: file.path)) != nil else {
      return file
    }
    return file.resolvingSymlinksInPath()
  }

  /// A file of ours alone: written whole, with no copy kept, because there
  /// was nothing of the user's in it to keep.
  public static func writeOurs(_ contents: String, to file: URL) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: destination(of: file), options: .atomic)
  }

  public static func render(_ object: [String: Any]) -> String {
    let data =
      (try? JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]))
      ?? Data()
    return String(decoding: data, as: UTF8.self) + "\n"
  }

  /// The file as it was before Multishell first touched it, held by contents
  /// and placed beside the link rather than in the repo it points into.
  private static func backUp(_ file: URL) throws {
    let backup = file.appendingPathExtension("before-multishell")
    guard FileManager.default.fileExists(atPath: file.path),
      !FileManager.default.fileExists(atPath: backup.path)
    else { return }
    try FileManager.default.copyItem(at: destination(of: file), to: backup)
  }
}
