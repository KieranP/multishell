/// The reader's files as they land out of order, and the row cap: the first file
/// whose rows before it reach the cap, and every file after, shows its header alone.
struct AllChangesReadSlots {
  private var files: [AllChangesFile?]
  private let rowCap: Int
  private var capIndex: Int?
  private var settled = 0
  private var heldRows = 0
  private var landedRows = 0

  var isCapped: Bool { capIndex != nil }
  /// Rows landed in any order reach the cap, so every file not yet read lies
  /// past it whatever an earlier file still out holds.
  var reachesRowCap: Bool { landedRows >= rowCap }

  init(count: Int, rowCap: Int) {
    files = Array(repeating: nil, count: count)
    self.rowCap = rowCap
  }

  mutating func land(_ file: AllChangesFile, at index: Int) {
    files[index] = file
    landedRows += file.rows?.lines.count ?? 0
    // Set as the cap is reached, not on the next file: the reader starts no
    // read past it, so that file may never land.
    while capIndex == nil, settled < files.count, let landed = files[settled] {
      heldRows += landed.rows?.lines.count ?? 0
      settled += 1
      if heldRows >= rowCap { capIndex = settled }
    }
  }

  /// Every listed file, past the cap or not yet read as such.
  func files(of listed: [(AllChangesFileChange, FileSignature?)]) -> [AllChangesFile] {
    listed.enumerated().map { index, entry in
      if let capIndex, index >= capIndex {
        return AllChangesFile(change: entry.0, content: .pastRowCap, signature: entry.1)
      }
      return files[index] ?? AllChangesFile(change: entry.0, content: .unread, signature: entry.1)
    }
  }
}
