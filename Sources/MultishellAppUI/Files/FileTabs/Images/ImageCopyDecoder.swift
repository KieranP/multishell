import CoreGraphics
import Foundation
import ImageIO

/// Decodes a file tab's image no larger than a screen needs, turned as its
/// orientation says; see Docs/design/files.md.
enum ImageCopyDecoder {
  /// Past this ImageIO's peak while scaling jumps, 130 MB to 430 for a 48-megapixel
  /// photo (files.md); decoded at 8 bits a channel it holds 36 MB.
  private static let longestSide = 3072
  private static let bitsPerPixel = 32

  /// One decode at a time, as the cap holds the peak only for one.
  private static let queue = DispatchQueue(label: "multishell.image-decode", qos: .userInitiated)

  /// In turn on `queue`; `nil` without decoding where the task was cancelled
  /// before its turn, a newer read having replaced the bytes.
  static func decodeInTurn(_ data: Data) async -> CGImage? {
    let cancellation = DecodeCancellation()
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        queue.async {
          continuation.resume(returning: cancellation.isRaised ? nil : decode(data))
        }
      }
    } onCancel: {
      cancellation.raise()
    }
  }

  /// Blocking: `decodeInTurn` runs it.
  static func decode(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: longestSide,
    ]
    guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    guard decoded.bitsPerPixel > bitsPerPixel else { return decoded }
    return redrawnShallower(decoded) ?? decoded
  }

  /// A 16-bit or HDR colour picture decodes at two to four times the bytes a
  /// pixel; redrawn in its own RGB space, so a wide gamut stays wide, else sRGB.
  private static func redrawnShallower(_ image: CGImage) -> CGImage? {
    let ownSpace = image.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
    // An EXR's extended-range space takes no 8-bit context, so sRGB stands in.
    let spaces = [ownSpace, CGColorSpace(name: CGColorSpace.sRGB)].compactMap(\.self)
    let contexts = spaces.lazy.compactMap { space in
      CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
      )
    }
    guard let context = contexts.first else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context.makeImage()
  }
}
