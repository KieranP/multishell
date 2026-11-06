import Foundation
import Testing

@testable import MultishellAppCore

@Suite
struct ShownImageCopyTests {
  @Test func aCaptionNamesItsSideOnlyWhereTwoCopiesAreDrawn() {
    let image = ImageFileBytes(
      data: Data(count: 2048),
      pixelSize: ImagePixelSize(width: 640, height: 480),
    )

    let alone = ShownImageCopy(image: image, source: .onDisk, side: nil).caption
    let before = ShownImageCopy(image: image, source: .committed, side: .before).caption

    #expect(alone.hasPrefix("640 × 480 pixels, "))
    #expect(alone.contains("KB"))
    #expect(before == "Before: " + alone)
  }

  @Test func onlyTheAfterCopyFollowsAnother() {
    let image = ImageFileBytes(data: Data(), pixelSize: ImagePixelSize(width: 1, height: 1))

    let sides: [ShownImageCopy.Side?] = [nil, .before, .after]

    #expect(
      sides.map { ShownImageCopy(image: image, source: .onDisk, side: $0).isAfterAnother } == [
        false, false, true,
      ]
    )
  }
}
