import Foundation

/// Reading and rewriting a JSON file an agent keeps its settings in.
///
/// The file is the user's, not ours: it is re-serialised on a write, so its
/// formatting changes, and the first write keeps a copy beside it. Anything
/// this cannot read back as a JSON object is refused rather than replaced.
/// Gemini's settings file takes comments, and Gemini keeps them when it
/// writes the file itself; a re-serialisation here would throw them away,
/// so a file with any in it is left alone and the entries are the user's to
/// paste.
public enum HookSettingsFile {
  /// An empty object for a missing or blank file; anything else this cannot
  /// read back and write out again is an error, since rewriting it would
  /// destroy what it could not read.
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

  /// Where a write lands. A settings file is often a symlink into a
  /// dotfiles repository, and an atomic write puts a regular file where the
  /// link was: the repository stops seeing the user's settings from then
  /// on, and the agent reads a file nothing is syncing. Written through
  /// instead, the way the agents' own settings commands do. Only a link at
  /// the end of the path is resolved, so every other path is written to
  /// exactly as it was given.
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

  /// The copy is of the file as it was before Multishell first touched it,
  /// so a later install does not overwrite it with one of our own writes.
  /// It holds the contents rather than a second link to them, and it goes
  /// beside the path the user knows: a copy left in the repository the link
  /// points into is a file their next `git status` has to explain.
  private static func backUp(_ file: URL) throws {
    let backup = file.appendingPathExtension("before-multishell")
    guard FileManager.default.fileExists(atPath: file.path),
      !FileManager.default.fileExists(atPath: backup.path)
    else { return }
    try FileManager.default.copyItem(at: destination(of: file), to: backup)
  }
}

public struct UnexpectedSettingsShape: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not a JSON object, so Multishell will not rewrite it."
  }
}

/// One event holds something other than the list of hooks the agent
/// documents. Ours is not written over it, since whatever is there is the
/// user's and this cannot put it back.
public struct UnreadableHookEntries: Error, CustomStringConvertible {
  public let file: URL
  public let event: String

  public init(file: URL, event: String) {
    self.file = file
    self.event = event
  }

  public var description: String {
    "\(file.path) holds something under hooks.\(event) that Multishell does not recognise."
  }
}

/// Not JSON this can read at all, a comment or a trailing comma being the
/// usual reason. Refused rather than parsed loosely and written back
/// strictly, which would take the comments with it.
public struct UnparsableSettingsFile: Error, CustomStringConvertible {
  public let file: URL

  public init(file: URL) { self.file = file }

  public var description: String {
    "\(file.path) is not plain JSON, so Multishell will not rewrite it."
  }
}
