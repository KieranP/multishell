/// One file of the All changes tab: how the Changes list counts it and what
/// its read gave, if it was read.
struct AllChangesFile: Equatable, Sendable {
  let change: AllChangesFileChange
  let content: AllChangesFileContent
  /// What the file looked like when read, `nil` for gone, so an event in its
  /// folder reads it again only where it moved.
  let signature: FileSignature?
  /// Rows kept from a read that a change since has outdated, away from the
  /// screen; read again as it nears it.
  var isStale = false

  var path: String { change.path }

  /// The file tab's reading of it, where it was read.
  var reading: FileTabReading? {
    if case .read(let reading) = content { reading } else { nil }
  }

  /// What its header counts: its rows', or the Changes list's where it has none
  /// or they are stale and count an older comparison.
  var lineCounts: FileLineCounts? {
    isStale ? change.lineCounts : rows?.lineCounts ?? change.lineCounts
  }

  /// Whether it shows rows to place a card under, or will once read; a notice
  /// or a file past the row cap places none.
  var holdsOrAwaitsRows: Bool { rows != nil || content == .unread }

  /// The rows, where the read gave some.
  var rows: FileTabRows? {
    guard case .text(let rows) = reading?.content else { return nil }
    return rows
  }
}
