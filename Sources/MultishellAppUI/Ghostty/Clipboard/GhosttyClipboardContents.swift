import GhosttyKit

/// The contents libghostty hands a clipboard callback, read for their text.
enum GhosttyClipboardContents {
  static let textMime = "text/plain"

  /// The plain text among clipboard contents, copied out of libghostty's
  /// buffers, which live only for the callback.
  static func plainText(in contents: UnsafeBufferPointer<ghostty_clipboard_content_s>) -> String? {
    contents.lazy.compactMap { content -> String? in
      guard let mime = content.mime, String(cString: mime) == textMime, let bytes = content.data
      else { return nil }
      return String(
        decoding: UnsafeRawBufferPointer(start: bytes, count: content.len), as: UTF8.self)
    }.first
  }

  /// A copy's text, `nil` for one to the selection clipboard or one Ghostty
  /// wants confirmed, which the app refuses as it refuses such a paste.
  static func textToWrite(
    _ contents: UnsafeBufferPointer<ghostty_clipboard_content_s>, at location: ghostty_clipboard_e,
    needsConfirming: Bool
  ) -> String? {
    guard location == GHOSTTY_CLIPBOARD_STANDARD, !needsConfirming else { return nil }
    return plainText(in: contents)
  }
}
