import Foundation
import MultishellAppCore
import TestScratch
import Testing
import UniformTypeIdentifiers

@testable import MultishellAppUI

@Suite
struct ImageFileRuleTests {
  @Test func aNameTypedAsAnImageImageIOReadsOpensAsOneAndSVGOrTextDoesNot() {
    #expect(ImageFileRule.opensAsImage(named: "assets/logo.png"))
    #expect(ImageFileRule.opensAsImage(named: "photo.HEIC"))
    #expect(ImageFileRule.opensAsImage(named: "favicon.ico"))
    #expect(!ImageFileRule.opensAsImage(named: "icon.svg"))
    #expect(!ImageFileRule.opensAsImage(named: "manual.pdf"))
    #expect(!ImageFileRule.opensAsImage(named: "README.md"))
    #expect(!ImageFileRule.opensAsImage(named: "Makefile"))
  }

  @Test func onlyARegularFileOpensAsAnImage() throws {
    let folder = try Scratch.directory("image-rule")
    defer { Scratch.remove(folder) }
    let packaged = folder.appending(path: "bundle.png", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: packaged, withIntermediateDirectories: true)
    let file = folder.appending(path: "logo.png")
    try EncodedImage.data(width: 2, height: 2).write(to: file)

    #expect(ImageFileRule.opensAsImage(file))
    #expect(!ImageFileRule.opensAsImage(packaged))
  }

  @Test func theSizeIsTheHeadersTurnedByItsOrientation() throws {
    let plain = try EncodedImage.data(width: 40, height: 10)
    let turned = try EncodedImage.data(width: 40, height: 10, as: .jpeg, orientation: 6)

    #expect(ImageFileRule.pixelSize(of: plain) == ImagePixelSize(width: 40, height: 10))
    #expect(ImageFileRule.pixelSize(of: turned) == ImagePixelSize(width: 10, height: 40))
    #expect(ImageFileRule.pixelSize(of: Data("not a picture".utf8)) == nil)
  }

  @Test func bytesThatReadAsTextAreNoImageThoughImageIOReadsThem() {
    let plainBitmap = Data("P1\n2 2\n0 1\n1 0\n".utf8)

    #expect(ImageFileRule.pixelSize(of: plainBitmap) == nil)
  }
}
