import Foundation
import ImageIO
import MultishellAppCore
import UniformTypeIdentifiers

/// Which files a file tab draws as an image, and their size; see
/// Docs/design/files/image-tabs.md.
enum ImageFileRule {
  /// What ImageIO decodes on this Mac, asked once.
  private static let decodedTypes = Set(CGImageSourceCopyTypeIdentifiers() as? [String] ?? [])

  static func opensAsImage(_ file: URL) -> Bool {
    let values = try? file.resourceValues(forKeys: [.isRegularFileKey])
    return values?.isRegularFile == true && opensAsImage(named: file.lastPathComponent)
  }

  /// An SVG is typed as an image and as text, and ImageIO reads none.
  static func opensAsImage(named name: String) -> Bool {
    guard let type = UTType(filenameExtension: (name as NSString).pathExtension) else {
      return false
    }
    return type.conforms(to: .image) && !type.conforms(to: .text)
      && decodedTypes.contains(type.identifier)
  }

  /// From the header, turned as its orientation turns it; `nil` for bytes
  /// reading as text, which wins as it does on opening.
  static func pixelSize(of data: Data) -> ImagePixelSize? {
    let start = data.prefix(TextFileStart.byteCount)
    guard !start.readsAsText(isCut: start.count < data.count),
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) > 0,
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0
    else { return nil }
    let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
    let isTurned = (5...8).contains(orientation)
    return ImagePixelSize(width: isTurned ? height : width, height: isTurned ? width : height)
  }
}
