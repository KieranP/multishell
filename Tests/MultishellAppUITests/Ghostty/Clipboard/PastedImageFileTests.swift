import AppKit
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite
@MainActor
struct PastedImageFileTests {
  private static let png = SamplePNG.data
  private static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47])
  private static let longAgo = Date(timeIntervalSinceReferenceDate: 0)

  private func save(
    _ pasteboard: NSPasteboard,
    in drops: URL,
  ) -> (urls: [URL], directory: URL, isNew: Bool)? {
    PastedImageFile.files(for: pasteboard, in: drops, saving: true)
  }

  @Test func aPNGIsSavedAsItCameInADirectoryOfItsOwn() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }

    let file = try #require(save(pasteboard, in: drops)?.urls.first)

    #expect(try Data(contentsOf: file) == Self.png)
    #expect(file.pathExtension == "png")
    #expect(file.deletingLastPathComponent().deletingLastPathComponent().path == drops.path)
  }

  @Test func aJPEGIsSavedAsItCameRatherThanReencoded() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let jpeg = try #require(
      NSBitmapImageRep(data: Self.png)?.representation(using: .jpeg, properties: [:])
    )
    let pasteboard = NSPasteboard.holding(jpeg, as: NSPasteboard.PasteboardType("public.jpeg"))
    defer { pasteboard.releaseGlobally() }

    let file = try #require(save(pasteboard, in: drops)?.urls.first)

    #expect(try Data(contentsOf: file) == jpeg)
    #expect(file.pathExtension == "jpg")
  }

  @Test func aGIFIsSavedAsItCameRatherThanReencoded() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let gif = try #require(
      NSBitmapImageRep(data: Self.png)?.representation(using: .gif, properties: [:])
    )
    let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
    let pasteboard = NSPasteboard.holding(gif, as: gifType)
    defer { pasteboard.releaseGlobally() }

    let file = try #require(save(pasteboard, in: drops)?.urls.first)

    #expect(try Data(contentsOf: file) == gif)
    #expect(file.pathExtension == "gif")
  }

  @Test func anItemOfferingSeveralFormatsIsSavedInTheOneItNamesFirst() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let jpeg = try #require(
      NSBitmapImageRep(data: Self.png)?.representation(using: .jpeg, properties: [:])
    )
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(jpeg, forType: NSPasteboard.PasteboardType("public.jpeg"))
    item.setData(Self.png, forType: .png)
    pasteboard.writeObjects([item])

    let file = try #require(save(pasteboard, in: drops)?.urls.first)

    #expect(file.pathExtension == "jpg")
  }

  @Test func aTIFFIsSavedAsAPNG() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let tiff = try #require(NSBitmapImageRep(data: Self.png)?.tiffRepresentation)
    let pasteboard = NSPasteboard.holding(tiff, as: .tiff)
    defer { pasteboard.releaseGlobally() }

    let file = try #require(save(pasteboard, in: drops)?.urls.first)

    #expect(try Data(contentsOf: file).prefix(4) == Self.pngSignature)
  }

  @Test func oneCopyPastedTwiceIsOneFile() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }

    let first = save(pasteboard, in: drops)
    let second = save(pasteboard, in: drops)

    #expect(first?.isNew == true)
    #expect(second?.isNew == false)
    #expect(first?.urls == second?.urls)
    #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).count == 1)
  }

  @Test func oneCopySavedForAnotherDirectoryIsSavedThereToo() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let otherDrops = try Scratch.directory("other-drops")
    defer { Scratch.remove(otherDrops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }

    _ = save(pasteboard, in: drops)
    let other = try #require(save(pasteboard, in: otherDrops))

    #expect(other.urls.first?.path.hasPrefix(otherDrops.path + "/") == true)
  }

  @Test func aCopyTheUserPastesAgainIsKeptFromTheSweepForAnotherWeek() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }
    let file = try #require(save(pasteboard, in: drops)?.urls.first)
    try FileManager.default.setAttributes(
      [.modificationDate: Self.longAgo],
      ofItemAtPath: file.deletingLastPathComponent().path,
    )

    _ = save(pasteboard, in: drops)
    DropCopies.sweep(in: drops, now: Date().addingTimeInterval(2 * 24 * 60 * 60))

    #expect(FileManager.default.fileExists(atPath: file.path))
  }

  @Test func aProgramsReadOfASavedCopyLeavesItsDateAlone() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }
    let directory = try #require(save(pasteboard, in: drops)?.directory)
    try FileManager.default.setAttributes(
      [.modificationDate: Self.longAgo],
      ofItemAtPath: directory.path,
    )

    _ = PastedImageFile.files(for: pasteboard, in: drops, saving: false)

    let dated = try FileManager.default.attributesOfItem(atPath: directory.path)[.modificationDate]
    #expect((dated as? Date) == Self.longAgo)
  }

  @Test func aNewCopyOfTheSameImageIsANewFile() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }

    let first = save(pasteboard, in: drops)
    pasteboard.clearContents()
    pasteboard.setData(Self.png, forType: .png)
    let second = save(pasteboard, in: drops)

    #expect(first != nil)
    #expect(second?.isNew == true)
    #expect(first?.urls != second?.urls)
  }

  @Test func aCopyWhoseFileWasSweptIsSavedAgain() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Self.png)
    defer { pasteboard.releaseGlobally() }

    let first = try #require(save(pasteboard, in: drops)?.urls.first)
    try FileManager.default.removeItem(at: first.deletingLastPathComponent())
    let second = try #require(save(pasteboard, in: drops)?.urls.first)

    #expect(FileManager.default.fileExists(atPath: second.path))
  }

  @Test func anImageThatCannotBeReadSavesNothingAndLeavesNoDirectory() throws {
    let drops = try Scratch.directory("drops")
    defer { Scratch.remove(drops) }
    let pasteboard = NSPasteboard.holding(Data("not an image".utf8), as: .tiff)
    defer { pasteboard.releaseGlobally() }

    #expect(save(pasteboard, in: drops) == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: drops.path).isEmpty)
  }
}
