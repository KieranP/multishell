import Foundation

/// One copy of an image file, kept as its bytes: the view decodes them,
/// so a hidden tab letting go of these holds no picture either.
public struct ImageFileBytes: Equatable, Sendable {
  public let data: Data
  public let pixelSize: ImagePixelSize
}
