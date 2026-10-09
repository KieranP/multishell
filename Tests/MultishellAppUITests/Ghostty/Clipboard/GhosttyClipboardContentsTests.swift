import Foundation
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttyClipboardContentsTests {
  @Test func aCopyIsReadForItsTextAndNothingElse() {
    let offered = ["image/png", GhosttyClipboardContents.textMime, "copied"]
    let read = CStrings.with(offered) { strings in
      let contents = [
        ghostty_clipboard_content_s(mime: strings[0], data: strings[2], len: 3),
        ghostty_clipboard_content_s(mime: strings[1], data: strings[2], len: strlen(strings[2])),
      ]
      return contents.withUnsafeBufferPointer(GhosttyClipboardContents.plainText(in:))
    }
    #expect(read == "copied")
  }

  @Test func onlyAPlainCopyToTheGeneralPasteboardHasTextToWrite() {
    let written = CStrings.with([GhosttyClipboardContents.textMime, "copied"]) { strings in
      let contents = [
        ghostty_clipboard_content_s(mime: strings[0], data: strings[1], len: strlen(strings[1]))
      ]
      return contents.withUnsafeBufferPointer { contents in
        [
          GhosttyClipboardContents.textToWrite(
            contents,
            at: GHOSTTY_CLIPBOARD_STANDARD,
            needsConfirming: false,
          ),
          GhosttyClipboardContents.textToWrite(
            contents,
            at: GHOSTTY_CLIPBOARD_SELECTION,
            needsConfirming: false,
          ),
          GhosttyClipboardContents.textToWrite(
            contents,
            at: GHOSTTY_CLIPBOARD_STANDARD,
            needsConfirming: true,
          ),
        ]
      }
    }
    #expect(written == ["copied", nil, nil])
  }
}
