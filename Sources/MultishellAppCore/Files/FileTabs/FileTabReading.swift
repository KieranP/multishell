/// A file tab's last read, runtime only: contents never reach `state.json`.
public struct FileTabReading: Equatable, Sendable {
  public let content: FileTabContent
  /// The file has gone from disk; the tab's title is struck through.
  public let isFileGone: Bool

  /// What a hidden tab lets go of, to read again when shown: rows or an image,
  /// but not a gone file's text, nor the copy on disk a gone image kept.
  var isLetGoWhenHidden: Bool {
    switch content {
    case .image(let image): !isFileGone || image.onDisk == nil
    case .text: !isFileGone
    case .binary, .missing, .released, .releasedFollowingStatus, .tooLarge, .unreadable: false
    }
  }

  var image: FileTabImage? {
    if case .image(let image) = content { image } else { nil }
  }
}
