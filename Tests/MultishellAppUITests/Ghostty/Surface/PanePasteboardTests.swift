import AppKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct PanePasteboardTests {
  @Test func copiedFilesPasteAsQuotedPaths() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([
      URL(fileURLWithPath: "/tmp/a b") as NSURL, URL(fileURLWithPath: "/tmp/c") as NSURL,
    ])
    #expect(PanePasteboard.pasteText(on: pasteboard) == "'/tmp/a b' /tmp/c")
  }

  @Test func aCopiedFileWhoseNameHoldsAControlCharacterIsLeftOut() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([
      URL(fileURLWithPath: "/tmp/a\nb") as NSURL, URL(fileURLWithPath: "/tmp/c") as NSURL,
    ])
    #expect(PanePasteboard.pasteText(on: pasteboard) == "/tmp/c")
  }

  /// Finder puts a copied file's name beside its URL as plain text.
  @Test func aCopiedFileLeftOutDoesNotPasteItsNameInstead() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/a\nb") as NSURL])
    pasteboard.setString("a\nb", forType: .string)
    #expect(PanePasteboard.pasteText(on: pasteboard) == nil)
  }

  @Test func textPastesAsItIs() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("echo hi", forType: .string)
    #expect(PanePasteboard.pasteText(on: pasteboard) == "echo hi")
  }

  @Test func pasteIsOfferedForTextOrFilesAndNothingElse() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    #expect(!PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.setData(Data([0x89, 0x50]), forType: .png)
    #expect(!PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.setString("echo hi", forType: .string)
    #expect(PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/c") as NSURL])
    #expect(PanePasteboard.hasPasteableType(on: pasteboard))
  }
}
