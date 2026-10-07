import Foundation

extension Scratch {
  /// A socket path under `/tmp`, not `$TMPDIR`: `sun_path` allows 104 bytes
  /// and the macOS temp directory alone is near that.
  public static func socketPath(_ tag: String) -> URL {
    URL(fileURLWithPath: "/tmp/ms-\(tag)-\(UUID().uuidString.prefix(8)).sock")
  }

  /// A socket and the claim file beside it, which the server keeps on purpose.
  public static func removeSocket(_ url: URL) {
    for path in [url.path, url.path + ".lock"] { try? FileManager.default.removeItem(atPath: path) }
  }
}
