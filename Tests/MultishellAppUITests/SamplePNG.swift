import AppKit

enum SamplePNG {
  static let data: Data = {
    let image = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: 2,
      pixelsHigh: 2,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0,
    )
    guard let png = image?.representation(using: .png, properties: [:]) else {
      preconditionFailure("AppKit encoded no PNG for the sample image")
    }
    return png
  }()
}
