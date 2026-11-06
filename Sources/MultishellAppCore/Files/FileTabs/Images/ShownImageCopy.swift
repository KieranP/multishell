import Foundation
import MultishellCore

/// One image a file tab draws, and the caption under it.
public struct ShownImageCopy: Equatable, Sendable {
  enum Side: Equatable, Sendable {
    case after
    case before
  }

  /// Which copy, so the view drawing it stays the one drawing it as a side
  /// comes or goes.
  public enum Source: Hashable, Sendable {
    case committed
    case onDisk
  }

  public let image: ImageFileBytes
  public let source: Source
  /// `nil` for a tab drawing one copy, which needs no label.
  let side: Side?

  /// The second of two, drawn after a divider.
  public var isAfterAnother: Bool { side == .after }

  /// Its side where there are two, its size in pixels and on disk.
  public var caption: String {
    let size = t(
      "file.image-size",
      String(image.pixelSize.width),
      String(image.pixelSize.height),
      ByteCountFormatter.string(fromByteCount: Int64(image.data.count), countStyle: .file),
    )
    switch side {
    case .after: return t("file.image-after", size)
    case .before: return t("file.image-before", size)
    case nil: return size
    }
  }
}
