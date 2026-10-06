import AppKit
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttyClipboardTests {
  @Test func copiedFilesPasteAsQuotedPaths() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([
      URL(fileURLWithPath: "/tmp/a b") as NSURL, URL(fileURLWithPath: "/tmp/c") as NSURL,
    ])
    #expect(GhosttyClipboard.pasteText(on: pasteboard) == "'/tmp/a b' /tmp/c")
  }

  @Test func aCopiedFileWhoseNameHoldsAControlCharacterIsLeftOut() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([
      URL(fileURLWithPath: "/tmp/a\nb") as NSURL, URL(fileURLWithPath: "/tmp/c") as NSURL,
    ])
    #expect(GhosttyClipboard.pasteText(on: pasteboard) == "/tmp/c")
  }

  /// Finder puts a copied file's name beside its URL as plain text.
  @Test func aCopiedFileLeftOutDoesNotPasteItsNameInstead() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/a\nb") as NSURL])
    pasteboard.setString("a\nb", forType: .string)
    #expect(GhosttyClipboard.pasteText(on: pasteboard) == nil)
  }

  @Test func textPastesAsItIs() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("echo hi", forType: .string)
    #expect(GhosttyClipboard.pasteText(on: pasteboard) == "echo hi")
  }

  @Test func pasteIsOfferedForTextOrFilesAndNothingElse() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    #expect(!GhosttyClipboard.hasPasteableType(on: pasteboard))
    pasteboard.setData(Data([0x89, 0x50]), forType: .png)
    #expect(!GhosttyClipboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.setString("echo hi", forType: .string)
    #expect(GhosttyClipboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/c") as NSURL])
    #expect(GhosttyClipboard.hasPasteableType(on: pasteboard))
  }

  @Test func aCopyIsReadForItsTextAndNothingElse() {
    let read = CStrings.with(["image/png", GhosttyClipboard.textMime, "copied"]) { strings in
      let contents = [
        ghostty_clipboard_content_s(mime: strings[0], data: strings[2], len: 3),
        ghostty_clipboard_content_s(mime: strings[1], data: strings[2], len: strlen(strings[2])),
      ]
      return contents.withUnsafeBufferPointer(GhosttyClipboard.copiedText(in:))
    }
    #expect(read == "copied")
  }

  @Test func onlyAPlainCopyToTheGeneralPasteboardHasTextToWrite() {
    let written = CStrings.with([GhosttyClipboard.textMime, "copied"]) { strings in
      let contents = [
        ghostty_clipboard_content_s(mime: strings[0], data: strings[1], len: strlen(strings[1]))
      ]
      return contents.withUnsafeBufferPointer { contents in
        [
          GhosttyClipboard.textToWrite(
            contents, at: GHOSTTY_CLIPBOARD_STANDARD, needsConfirming: false),
          GhosttyClipboard.textToWrite(
            contents, at: GHOSTTY_CLIPBOARD_SELECTION, needsConfirming: false),
          GhosttyClipboard.textToWrite(
            contents, at: GHOSTTY_CLIPBOARD_STANDARD, needsConfirming: true),
        ]
      }
    }
    #expect(written == ["copied", nil, nil])
  }
}
