import Foundation

@testable import MultishellAppCore

extension FileTabImage {
  /// A new file's one copy on disk, `byteCount` bytes of a 1 × 1 picture.
  static func onDiskOnly(byteCount: Int = 1) -> Self {
    let bytes = ImageFileBytes(
      data: Data(count: byteCount),
      pixelSize: ImagePixelSize(width: 1, height: 1),
    )
    return Self(onDisk: bytes, committed: nil, committedObjectID: nil, isChanged: false)
  }
}
