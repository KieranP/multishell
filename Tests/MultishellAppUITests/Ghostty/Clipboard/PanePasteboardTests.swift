import AppKit
import TestScratch
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct PanePasteboardTests {
  private func pasteText(
    on pasteboard: NSPasteboard,
    dropsDirectory directory: URL = Scratch.path("drops"),
    isUsersPaste: Bool = true,
    typing: ([URL]) -> String? = { $0.map(\.lastPathComponent).joined(separator: " ") },
  ) -> (text: String?, typedFiles: [URL]) {
    var typedFiles: [URL] = []
    let text = PanePasteboard.pasteText(
      on: pasteboard,
      dropsDirectory: directory,
      isUsersPaste: isUsersPaste,
    ) { files in
      typedFiles += files
      return typing(files)
    }
    return (text, typedFiles)
  }

  @Test func copiedFilesPasteAsTheSessionTypesThem() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([
      URL(fileURLWithPath: "/tmp/a b") as NSURL, URL(fileURLWithPath: "/tmp/c") as NSURL,
    ])

    let paste = pasteText(on: pasteboard)

    #expect(paste.text == "a b c")
    #expect(paste.typedFiles.map(\.path) == ["/tmp/a b", "/tmp/c"])
  }

  @Test func copiedFilesReadByAProgramAreQuotedPathsNotTheSessionsWords() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([
      URL(fileURLWithPath: "/tmp/a b") as NSURL, URL(fileURLWithPath: "/tmp/c") as NSURL,
    ])

    let paste = pasteText(on: pasteboard, isUsersPaste: false)

    #expect(paste.text == "'/tmp/a b' /tmp/c")
    #expect(paste.typedFiles.isEmpty)
  }

  @Test func severalCopiedImagesPasteAsTheirFiles() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    let items = (0..<2).map { _ in
      let item = NSPasteboardItem()
      item.setData(SamplePNG.data, forType: .png)
      return item
    }
    pasteboard.writeObjects(items)

    let paste = pasteText(on: pasteboard, dropsDirectory: drops)

    #expect(paste.typedFiles.count == 2)
    #expect(Set(paste.typedFiles).count == 2)
  }

  /// Finder puts a copied file's name beside its URL as plain text.
  @Test func copiedFilesTheSessionLeavesOutDoNotPasteTheirNamesInstead() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/a\nb") as NSURL])
    pasteboard.setString("a\nb", forType: .string)

    let text = pasteText(on: pasteboard, typing: { _ in nil }).text

    #expect(text == nil)
  }

  @Test func textPastesAsItIs() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("echo hi", forType: .string)

    let paste = pasteText(on: pasteboard)

    #expect(paste.text == "echo hi")
    #expect(paste.typedFiles.isEmpty)
  }

  @Test func anImageAlonePastesAsTheFileItIsSavedTo() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }

    let paste = pasteText(on: pasteboard, dropsDirectory: drops)

    let file = try #require(paste.typedFiles.first)
    #expect(paste.typedFiles.count == 1)
    #expect(paste.text == file.lastPathComponent)
    #expect(file.path.hasPrefix(drops.path + "/"))
    #expect(try Data(contentsOf: file) == SamplePNG.data)
  }

  @Test func anImageNotYetSavedIsNeitherSavedNorTypedForAReadThatMayNotSaveOne() throws {
    let drops = Scratch.path("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }

    let paste = pasteText(on: pasteboard, dropsDirectory: drops, isUsersPaste: false)

    #expect(paste.text == nil)
    #expect(paste.typedFiles.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: drops.path))
  }

  @Test func anImageAlreadySavedIsAQuotedPathForAProgramsRead() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }

    let saved = pasteText(on: pasteboard, dropsDirectory: drops, isUsersPaste: true)
    let reused = pasteText(on: pasteboard, dropsDirectory: drops, isUsersPaste: false)

    let file = try #require(saved.typedFiles.first)
    #expect(reused.typedFiles.isEmpty)
    #expect(reused.text == file.path)
  }

  @Test func anImageTheSessionWillNotTypeLeavesNoFileBehind() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }

    let text = pasteText(on: pasteboard, dropsDirectory: drops, typing: { _ in nil }).text

    #expect(text == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).isEmpty)
  }

  @Test func aSessionRefusingAnImageAlreadyTypedElsewhereLeavesItsFile() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }

    let typed = try #require(pasteText(on: pasteboard, dropsDirectory: drops).typedFiles.first)
    _ = pasteText(on: pasteboard, dropsDirectory: drops, typing: { _ in nil })

    #expect(FileManager.default.fileExists(atPath: typed.path))
  }

  @Test func anEmptyTextBesideAnImageLeavesTheImageToPaste() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }
    pasteboard.setString("", forType: .string)

    let paste = pasteText(on: pasteboard, dropsDirectory: drops)

    #expect(paste.typedFiles.count == 1)
  }

  @Test func whitespaceBesideAnImageLeavesTheImageToPaste() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }
    pasteboard.setString(" \n", forType: .string)

    let paste = pasteText(on: pasteboard, dropsDirectory: drops)

    #expect(paste.typedFiles.count == 1)
  }

  /// NSTextView writes U+FFFC as the plain text of a selection that is only an
  /// attachment.
  @Test func anAttachmentsPlaceholderBesideAnImageLeavesTheImageToPaste() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }
    pasteboard.setString("\u{FFFC}\n", forType: .string)

    let paste = pasteText(on: pasteboard, dropsDirectory: drops)

    #expect(paste.typedFiles.count == 1)
  }

  @Test func whitespaceAlonePastesAsItIs() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString(" \n", forType: .string)

    #expect(pasteText(on: pasteboard).text == " \n")
  }

  @Test func anEmptyTextAlonePastesAsEmptyText() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("", forType: .string)

    #expect(pasteText(on: pasteboard).text == "")
  }

  /// Office and Keynote put an image of a copied selection beside its text.
  @Test func textBesideAnImagePastesTheTextAndSavesNothing() throws {
    let drops = Scratch.path("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(SamplePNG.data)
    defer { pasteboard.releaseGlobally() }
    pasteboard.setString("A1\tB1", forType: .string)

    let paste = pasteText(on: pasteboard, dropsDirectory: drops)

    #expect(paste.text == "A1\tB1")
    #expect(!FileManager.default.fileExists(atPath: drops.path))
  }

  @Test func pasteIsOfferedForTextFilesOrAnImageAndNothingElse() {
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    #expect(!PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.setData(Data([1]), forType: NSPasteboard.PasteboardType("com.example.private"))
    #expect(!PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.setData(SamplePNG.data, forType: .png)
    #expect(PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.setData(SamplePNG.data, forType: .tiff)
    #expect(PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.setString("echo hi", forType: .string)
    #expect(PanePasteboard.hasPasteableType(on: pasteboard))
    pasteboard.clearContents()
    pasteboard.writeObjects([URL(fileURLWithPath: "/tmp/c") as NSURL])
    #expect(PanePasteboard.hasPasteableType(on: pasteboard))
  }
}
