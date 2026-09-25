import Foundation

/// A per-test directory under the temporary directory. This suite reaches
/// neither shared test target, so it keeps its own copy of `Scratch`'s.
enum ScratchDirectory {
  /// Not created, for a test checking the code under test makes it.
  static func path(_ tag: String) -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("multishell-\(tag)-\(UUID().uuidString)", isDirectory: true)
  }

  static func make(_ tag: String) throws -> URL {
    let url = path(tag)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  static func remove(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
