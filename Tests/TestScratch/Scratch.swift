import Foundation

@testable import MultishellProcess

/// No git layer, so every test target can use it without linking the
/// GitKit that `TestSupport` needs.
public enum Scratch {
  /// Not created: several tests check that the code under test makes it. `tag` only marks a
  /// stray directory a crashed test left behind; nothing reads it.
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

  /// A shell's whole environment: the system PATH, no history file, and a
  /// scratch home, so nothing of the developer's is read or written.
  public static func bareShellEnvironment(home: URL) -> [String: String] {
    ["PATH": "/usr/bin:/bin", "HISTFILE": "", "HOME": home.path]
  }

  /// A socket path under `/tmp`, not `$TMPDIR`: `sun_path` allows 104 bytes
  /// and the macOS temp directory alone is near that.
  public static func socketPath(_ tag: String) -> URL {
    URL(fileURLWithPath: "/tmp/ms-\(tag)-\(UUID().uuidString.prefix(8)).sock")
  }

  /// A socket and the claim file beside it, which the server keeps on purpose.
  public static func removeSocket(_ url: URL) {
    for path in [url.path, url.path + ".lock"] { try? FileManager.default.removeItem(atPath: path) }
  }

  /// An exported `HISTFILE` had an interactive bash append each test's commands to the
  /// developer's own. Empty, not absent, as `ProcessRunner` merges it over its own environment.
  public static var shellEnvironment: [String: String] {
    ShellInvocation.historyless(ProcessInfo.processInfo.environment)
  }

  /// As `realpath` gives it, which a shell's `pwd -P` matches: `/private/var`
  /// where Foundation says `/var`. `nil` for a path that does not exist.
  public static func physicalPath(of url: URL) -> String? {
    guard let resolved = realpath(url.path, nil) else { return nil }
    defer { free(resolved) }
    return String(cString: resolved)
  }

  /// Removes a path if it is there, for a `defer` or a `tearDown`.
  public static func remove(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}
