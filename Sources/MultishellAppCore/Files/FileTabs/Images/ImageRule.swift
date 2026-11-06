import Foundation

/// The platform's answers on images, asked by a file tab's read off the main
/// actor: the type check loads ImageIO's list on first use.
struct ImageRule: Sendable {
  /// A name typed as an image the platform decodes, and not as text.
  let opensAsImage: @Sendable (String) -> Bool
  /// From the header, `nil` for bytes no decoder reads or that read as text.
  let pixelSize: @Sendable (Data) -> ImagePixelSize?
}
