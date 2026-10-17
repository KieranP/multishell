import Foundation
import MultishellProcess

/// What git holds of one file, read by size before by content, for a file tab
/// and the Files panel's open rule; see Docs/design/files.md.
extension WorktreeGit {
  /// `HEAD`'s copy's size, `nil` where it has none; asked first, so a small file
  /// whose last commit is huge never diffs into memory.
  public func committedSize(of path: String, in directory: URL) async throws -> Int? {
    try await size(of: "HEAD:\(path)", in: directory)
  }

  /// The first `byteCount` bytes of git's copy of a gone file, the index's
  /// else `HEAD`'s; empty past `sizeLimit`, `nil` where git has none.
  public func storedCopyStart(
    of path: String,
    in directory: URL,
    byteCount: Int,
    sizeLimit: Int,
  ) async -> Data? {
    // `:0:`, as `:1:notes.txt` alone names stage one of `notes.txt`.
    for object in [":0:\(path)", "HEAD:\(path)"] {
      guard let size = try? await size(of: object, in: directory) else { continue }
      guard size <= sizeLimit else { return Data() }
      return await runner.outputBytes(["cat-file", "blob", object], in: directory)?.prefix(
        byteCount
      )
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
