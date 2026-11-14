/// What the All changes tab holds of one file.
enum AllChangesFileContent: Equatable, Sendable {
  /// A file its name types as an image: its notice alone, the bytes left for
  /// its own tab to read.
  case image
  /// Past the rows the tab holds in all, so only its header shows; see
  /// Docs/design/files/all-changes-tab.md.
  case pastRowCap
  /// What a file tab's read of it gives, so it reads the same in both.
  case read(FileTabReading)
  /// Listed since the last read, which has yet to reach it.
  case unread
}
