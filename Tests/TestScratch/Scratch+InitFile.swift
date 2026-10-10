import Foundation

extension Scratch {
  /// An empty file where a bash or fish integration script would be, for a
  /// launch that only runs one that exists.
  public static func initFileThatExists() throws -> URL {
    let url = path("initfile")
    try "".write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}
