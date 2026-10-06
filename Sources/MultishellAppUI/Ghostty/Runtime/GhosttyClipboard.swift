import AppKit
import GhosttyKit
import MultishellAppCore

/// The general pasteboard as a pane reads and writes it: text alone, the one
/// thing a pane pastes or copies.
enum GhosttyClipboard {
  static let textMime = "text/plain"

  /// What a paste types: copied files as a drop types them, or else the text.
  /// Files all left out type nothing, Finder's text being their names.
  @MainActor
  static func pasteText(on pasteboard: NSPasteboard = .general) -> String? {
    let files = pasteboard.fileURLs
    guard files.isEmpty else { return FilePathText.pastedText(for: files) }
    return pasteboard.string(forType: .string)
  }

  /// Asked of the types alone, as menu validation runs too often to build the
  /// text; a file `pasteText(on:)` leaves out still counts.
  @MainActor
  static func hasPasteableType(on pasteboard: NSPasteboard = .general) -> Bool {
    pasteboard.availableType(from: [.fileURL, .string]) != nil
  }

  /// The text among what a copy offers, copied out of libghostty's buffers,
  /// which live only for the callback.
  static func copiedText(in contents: UnsafeBufferPointer<ghostty_clipboard_content_s>) -> String? {
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
    return copiedText(in: contents)
  }

  @MainActor
  static func write(_ text: String, to pasteboard: NSPasteboard = .general) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}
