import Foundation

extension Scratch {
  /// An empty file where a bash integration script would be, for a launch
  /// that only runs one that exists.
  public static func bashInitThatExists() throws -> URL {
    let url = path("bashinit")
    try "".write(to: url, atomically: true, encoding: .utf8)
    return url
  }
}
