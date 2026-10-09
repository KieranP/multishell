import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyPasteConfirmationTests {
  private func confirmation(
    _ kind: ghostty_clipboard_request_e,
    text: String?,
  ) -> GhosttyPasteConfirmation? {
    CStrings.with([GhosttyClipboardContents.textMime, text ?? ""]) { strings in
      let contents =
        text == nil
        ? []
        : [
          ghostty_clipboard_content_s(mime: strings[0], data: strings[1], len: strlen(strings[1]))
        ]
      return contents.withUnsafeBufferPointer { buffer in
        GhosttyPasteConfirmation(
          GhosttyClipboardRequest(handle: nil),
          kind: kind,
          contents: buffer,
        )
      }
    }
  }

  @Test func anUnsafePasteIsAskedAboutWithTheTextItWouldType() {
    #expect(confirmation(GHOSTTY_CLIPBOARD_REQUEST_PASTE, text: "ls\nrm x")?.text == "ls\nrm x")
  }

  @Test func aProgramsReadWriteOrListingIsRefusedUnasked() {
    for kind in [
      GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ, GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE,
      GHOSTTY_CLIPBOARD_REQUEST_KITTY_READ, GHOSTTY_CLIPBOARD_REQUEST_KITTY_WRITE,
      GHOSTTY_CLIPBOARD_REQUEST_LIST,
    ] {
      #expect(confirmation(kind, text: "secret") == nil, "\(kind)")
    }
  }

  @Test func aPasteWithNoTextIsRefusedUnasked() {
    #expect(confirmation(GHOSTTY_CLIPBOARD_REQUEST_PASTE, text: nil) == nil)
  }
}
