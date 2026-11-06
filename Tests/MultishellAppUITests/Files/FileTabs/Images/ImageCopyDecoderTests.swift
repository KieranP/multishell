import CoreGraphics
import Foundation
import Testing
import UniformTypeIdentifiers

@testable import MultishellAppUI

@Suite
struct ImageCopyDecoderTests {
  @Test func aPictureWiderThanAnyDisplayIsDecodedSmallerAndAPlainOneWhole() throws {
    let wide = try #require(ImageCopyDecoder.decode(EncodedImage.data(width: 4000, height: 50)))
    let plain = try #require(ImageCopyDecoder.decode(EncodedImage.data(width: 30, height: 20)))

    #expect(wide.width == 3072)
    #expect((plain.width, plain.height) == (30, 20))
  }

  @Test func aPhotoIsDecodedTurnedAsItsOrientationSays() throws {
    let photo = try EncodedImage.data(width: 40, height: 10, as: .jpeg, orientation: 6)

    let decoded = try #require(ImageCopyDecoder.decode(photo))

    #expect((decoded.width, decoded.height) == (10, 40))
  }

  @Test func aSixteenBitPictureIsDecodedAtEightBitsAChannel() throws {
    let deep = try EncodedImage.data(width: 20, height: 20, bitsPerComponent: 16)

    let decoded = try #require(ImageCopyDecoder.decode(deep))

    #expect(decoded.bitsPerComponent == 8)
    #expect(decoded.bitsPerPixel == 32)
  }

  @Test func aSixteenBitGreyPictureIsKeptAsItHoldsNoMoreThanEightBitColour() throws {
    let grey = try EncodedImage.data(
      width: 20,
      height: 20,
      bitsPerComponent: 16,
      colorSpace: CGColorSpace.linearGray,
    )

    let decoded = try #require(ImageCopyDecoder.decode(grey))

    #expect(decoded.bitsPerPixel == 16)
  }

  @Test func aSixteenBitWideGamutPictureKeepsItsColourSpace() throws {
    let wide = try EncodedImage.data(
      width: 20,
      height: 20,
      bitsPerComponent: 16,
      colorSpace: CGColorSpace.displayP3,
    )

    let decoded = try #require(ImageCopyDecoder.decode(wide))

    #expect(decoded.bitsPerPixel == 32)
    #expect(decoded.colorSpace?.name == CGColorSpace.displayP3)
  }

  @Test func aDecodeInTurnDecodesWhereOneCancelledBeforeItsTurnDecodesNothing() async throws {
    let data = try EncodedImage.data(width: 20, height: 20)

    let decoded = await ImageCopyDecoder.decodeInTurn(data)
    let cancelled = await withTaskGroup(of: CGImage?.self) { group in
      group.cancelAll()
      group.addTask { await ImageCopyDecoder.decodeInTurn(data) }
      return await group.next() ?? nil
    }

    #expect(decoded?.width == 20)
    #expect(cancelled == nil)
  }

  @Test func aFloatHDRPictureIsDrawnAgainAtEightBitsAChannel() throws {
    let exr = try #require(UTType("com.ilm.openexr-image"))
    let hdr = try EncodedImage.data(
      width: 20,
      height: 20,
      as: exr,
      bitsPerComponent: 32,
      colorSpace: CGColorSpace.extendedLinearSRGB,
    )

    let decoded = try #require(ImageCopyDecoder.decode(hdr))

    #expect(decoded.bitsPerPixel == 32)
  }

  @Test func bytesNoDecoderReadsGiveNoImage() {
    #expect(ImageCopyDecoder.decode(Data("not a picture".utf8)) == nil)
  }
}
