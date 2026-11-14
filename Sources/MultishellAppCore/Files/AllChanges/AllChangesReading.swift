/// An All changes tab's last read, runtime only: every listed file in the
/// Changes list's order.
public struct AllChangesReading: Equatable, Sendable {
  /// The list the read was given, so a status read listing the same reads nothing.
  let listed: [AllChangesFileChange]
  public let files: [AllChangesFile]

  /// What the bar counts: every file's rows, or the list's count where none.
  public var lineCounts: FileLineCounts {
    files.reduce(FileLineCounts(insertions: 0, deletions: 0)) { total, file in
      let counts = file.rows?.lineCounts ?? file.change.lineCounts
      return FileLineCounts(
        insertions: total.insertions + (counts?.insertions ?? 0),
        deletions: total.deletions + (counts?.deletions ?? 0),
      )
    }
  }
}
