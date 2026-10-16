import Foundation
import MultishellAppCore

extension URL {
  /// Valid UTF-8 with no zero byte in its first 8 KB, git's test and more. macOS has
  /// no text type for a `.rs` or a `Dockerfile`, and calls a `.ts` a video.
  func readsAsText() -> Bool {
    guard let handle = try? FileHandle(forReadingFrom: self) else { return false }
    defer { try? handle.close() }
    let start = (try? handle.read(upToCount: TextFileStart.byteCount)) ?? Data()
    return start.readsAsText(isCut: start.count == TextFileStart.byteCount)
  }
}
