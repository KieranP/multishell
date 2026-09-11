import Foundation

/// Throwaway paths under the system temp directory.
///
/// Every suite needs one and they were hand-rolled per test, so the same four
/// lines appeared fifty times with a different tag each. `tag` is only there
/// to make a stray directory recognisable when a test crashes before its
/// teardown; nothing reads it.
///
/// No dependencies, so the test targets for the Foundation-only libraries can
/// use it without linking the git layer that `TestSupport` needs.
public enum Scratch {
  /// A unique directory URL. Not created: several tests hand the path to the
  /// code under test precisely to check that it makes it.
  public static func path(_ tag: String = "scratch") -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-\(tag)-\(UUID().uuidString)", isDirectory: true)
  }

  /// The same, created.
  public static func directory(_ tag: String = "scratch") throws -> URL {
    let url = path(tag)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// An executable `/bin/sh` script holding `body`, for standing in for a
  /// program the code under test looks up on a PATH.
  @discardableResult
  public static func script(_ body: String, at url: URL) throws -> URL {
    try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
  }

  /// Removes a path if it is there, for a `defer` or a `tearDown`.
  public static func remove(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
