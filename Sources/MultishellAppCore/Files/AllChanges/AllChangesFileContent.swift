/// What the All changes tab holds of one file.
public enum AllChangesFileContent: Equatable, Sendable {
  /// Past the rows the tab holds in all, so only its header shows; see
  /// Docs/design/files/all-changes-tab.md.
  case pastRowCap
  /// What a file tab's read of it gives, so it reads the same in both.
  case read(FileTabReading)
  /// Listed since the last read, which has yet to reach it.
  case unread
}
