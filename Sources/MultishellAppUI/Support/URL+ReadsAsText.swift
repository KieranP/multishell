import Foundation

extension URL {
  private static let bytesReadForTextCheck = 8192

  /// Valid UTF-8 with no zero byte in its first 8 KB, git's test and more. macOS has
  /// no text type for a `.rs` or a `Dockerfile`, and calls a `.ts` a video.
  func readsAsText() -> Bool {
    guard let handle = try? FileHandle(forReadingFrom: self) else { return false }
    defer { try? handle.close() }
    let start = (try? handle.read(upToCount: Self.bytesReadForTextCheck)) ?? Data()
    guard !start.contains(0) else { return false }
    // A read that stopped mid-character cut up to three bytes off its end.
    let cut = start.count == Self.bytesReadForTextCheck ? 0...3 : 0...0
    return cut.contains { String(validating: start.dropLast($0), as: UTF8.self) != nil }
  }
}
