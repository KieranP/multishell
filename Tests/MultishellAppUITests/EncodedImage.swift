import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// A plain image encoded as a file holds it, with the orientation and depth asked.
enum EncodedImage {
  static func data(
    width: Int,
    height: Int,
    as type: UTType = .png,
    orientation: Int = 1,
    bitsPerComponent: Int = 8,
    colorSpace: CFString = CGColorSpace.sRGB,
  ) throws
    -> Data
  {
    let space = try #require(CGColorSpace(name: colorSpace))
    let alpha = space.model == .monochrome ? CGImageAlphaInfo.none : .premultipliedLast
    let order: UInt32 =
      switch bitsPerComponent {
      case 16: CGBitmapInfo.byteOrder16Little.rawValue
      case 32: CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
      default: 0
      }
    let context = try #require(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: 0,
        space: space,
        bitmapInfo: alpha.rawValue | order,
      )
    )
    context.setFillColor(CGColor(gray: 0.5, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let data = NSMutableData()
    let destination = try #require(
      CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)
    )
    let properties = [kCGImagePropertyOrientation: orientation] as CFDictionary
    CGImageDestinationAddImage(destination, image, properties)
    try #require(CGImageDestinationFinalize(destination))
    return data as Data
  }
}
