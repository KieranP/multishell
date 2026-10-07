import GhosttyKit

/// A paste libghostty judges unsafe, held while the user is asked: the text is
/// copied out of buffers that live only for the callback.
struct GhosttyPasteConfirmation: Sendable {
  let request: GhosttyClipboardRequest
  let text: String

  /// `nil` for anything but a paste with text: a program's read or write is
  /// refused unasked; see Docs/design/terminals.md.
  init?(
    _ request: GhosttyClipboardRequest, kind: ghostty_clipboard_request_e,
    contents: UnsafeBufferPointer<ghostty_clipboard_content_s>
  ) {
    guard kind == GHOSTTY_CLIPBOARD_REQUEST_PASTE,
      let text = GhosttyClipboard.plainText(in: contents)
    else { return nil }
    self.request = request
    self.text = text
  }
}
