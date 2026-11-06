import Foundation

@testable import MultishellAppCore

/// Bytes `FakePlatform` reads as an image: a PNG-like signature, holding a
/// zero byte as a real one does, then its width and height.
enum FakeImage {
  private static let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x00])

  static func bytes(width: UInt8, height: UInt8, mark: UInt8 = 0, padding: Int = 0) -> Data {
    signature + Data([width, height, mark]) + Data(count: padding)
  }

  static func pixelSize(of data: Data) -> ImagePixelSize? {
    guard data.count >= signature.count + 3, data.starts(with: signature) else { return nil }
    let bytes = [UInt8](data)
    return ImagePixelSize(width: Int(bytes[5]), height: Int(bytes[6]))
  }
}
