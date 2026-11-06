import Foundation
import MultishellProcess

/// What git holds of one file, read by size before by content, for a file tab
/// and the Files panel's open rule; see Docs/design/files.md.
extension WorktreeGit {
  /// `:0:`, as `:1:notes.txt` alone names stage one of `notes.txt`.
  private static func storedObjectNames(of path: String) -> [String] {
    [":0:\(path)", "HEAD:\(path)"]
  }

  /// The copy's size in `commit`, else `HEAD`, `nil` where it has none; asked
  /// first, so a small file whose last commit is huge never diffs into memory.
  public func committedSize(
    of path: String,
    in directory: URL,
    at commit: String? = nil,
  ) async throws -> Int? {
    try await size(of: "\(commit ?? "HEAD"):\(path)", in: directory)
  }

  /// The copy's object id in `commit`, else `HEAD`, `nil` where it has none;
  /// a read that cannot say throws. Its bytes come from `objectBytes`.
  public func committedObjectID(
    of path: String,
    in directory: URL,
    at commit: String? = nil,
  ) async throws -> String? {
    let object = "\(commit ?? "HEAD"):\(path)"
    // `--verify --quiet` exits 1, and only 1, for a name that resolves to nothing.
    do {
      return try await runner.run(["rev-parse", "--verify", "--quiet", object], in: directory)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    } catch let failure as ProcessFailure where failure.status == 1 {
      return nil
    }
  }

  /// An object's size by its id, `nil` where git has no such object.
  public func objectSize(_ objectID: String, in directory: URL) async throws -> Int? {
    try await size(of: objectID, in: directory)
  }

  /// An object's bytes by its name or id, an id naming the same bytes whatever
  /// `HEAD` has done since; the caller asks the size first.
  public func objectBytes(_ object: String, in directory: URL) async -> Data? {
    await runner.outputBytes(["cat-file", "blob", object], in: directory)
  }

  /// Whether git holds a copy of a gone file, the index's or `HEAD`'s, asked
  /// without reading it.
  public func hasStoredCopy(of path: String, in directory: URL) async -> Bool {
    await storedObject(of: path, in: directory) != nil
  }

  /// The first `byteCount` bytes of git's copy of a gone file, the index's
  /// else `HEAD`'s; empty past `sizeLimit`, `nil` where git has none.
  public func storedCopyStart(
    of path: String,
    in directory: URL,
    byteCount: Int,
    sizeLimit: Int,
  ) async -> Data? {
    guard let (object, size) = await storedObject(of: path, in: directory) else { return nil }
    guard size <= sizeLimit else { return Data() }
    return await objectBytes(object, in: directory)?.prefix(byteCount)
  }

  /// The index's copy, else `HEAD`'s, by name and size.
  private func storedObject(of path: String, in directory: URL) async -> (String, Int)? {
    for object in Self.storedObjectNames(of: path) {
      guard let size = try? await size(of: object, in: directory) else { continue }
      return (object, size)
    }
    return nil
  }

  /// Exit 128 is an object git does not have, which is no size, not a failure.
  private func size(of object: String, in directory: URL) async throws -> Int? {
    do {
      let output = try await runner.run(["cat-file", "-s", object], in: directory)
      return Int(output.trimmingCharacters(in: .whitespacesAndNewlines))
    } catch let failure as ProcessFailure where failure.status == 128 {
      return nil
    }
  }
}
