/// A file tab's last read, runtime only: contents never reach `state.json`.
public struct FileTabReading: Equatable, Sendable {
  public let content: FileTabContent
  /// The file has gone from disk; the tab's title is struck through.
  public let isFileGone: Bool
}
