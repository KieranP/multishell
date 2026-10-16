import Foundation
import MultishellAppCore
import UniformTypeIdentifiers

/// Which files open as text: in the editor from a clicked link, and in a file
/// tab from the Files panel, by one rule; see Docs/design/files.md.
enum TextFileRule {
  /// A regular file typed as text, or reading as text: macOS has no text type
  /// for a `.rs` or a `Dockerfile`, and calls a `.ts` a video.
  static func opensAsText(_ file: URL) -> Bool {
    let values = try? file.resourceValues(forKeys: [.contentTypeKey, .isRegularFileKey])
    guard values?.isRegularFile == true else { return false }
    return values?.contentType?.conforms(to: .text) == true || file.readsAsText()
  }

  static func opensAsText(named name: String, startingWith bytes: Data) -> Bool {
    let type = UTType(filenameExtension: (name as NSString).pathExtension)
    return type?.conforms(to: .text) == true
      || bytes.readsAsText(isCut: bytes.count >= TextFileStart.byteCount)
  }
}
