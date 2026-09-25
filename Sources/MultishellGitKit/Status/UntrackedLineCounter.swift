import Foundation

/// Lines in the files git lists as untracked, which have no diff until they
/// are added; see Docs/design/worktrees.md.
enum UntrackedLineCounter {
  /// A poll's share of the disk: how many files it opens, how big one may be,
  /// and how much it reads in all before it stops counting.
  static let fileLimit = 500
  static let byteLimit = 1 << 20
  static let totalByteLimit = 8 << 20

  /// Every line an insertion; `unscored` is the files with no line to show:
  /// binary, empty, or unread. Never one past `fileLimit`; see worktrees.md.
  static func count(
    paths: [String], in directory: URL, memo: UntrackedLineMemo? = nil
  ) -> LineCounts {
    let known = memo?.entries(in: directory) ?? [:]
    var seen: [String: UntrackedLineMemo.Entry] = [:]
    var counts = LineCounts()
    var read = 0
    for path in paths.prefix(fileLimit) {
      let url = directory.appending(path: path)
      // A symlink is not a regular file, so it is never read: its own size
      // is not its target's and the read would follow it.
      guard
        let values = try? url.resourceValues(
          forKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey]),
        values.isRegularFile == true, let size = values.fileSize, size <= byteLimit,
        read + size <= totalByteLimit
      else {
        counts.unscored += 1
        continue
      }
      let modified = values.contentModificationDate ?? .distantPast
      let counted: Int?
      if let entry = known[path], entry.size == size, entry.modified == modified {
        counted = entry.lines
      } else if let data = try? Data(contentsOf: url) {
        counted = Self.lines(in: data)
      } else {
        // Unread is not remembered: a file made readable keeps its date.
        counts.unscored += 1
        continue
      }
      // Charged whether read or remembered, so the budget skips what it did.
      read += size
      seen[path] = UntrackedLineMemo.Entry(size: size, modified: modified, lines: counted)
      if let counted { counts.insertions += counted } else { counts.unscored += 1 }
    }
    memo?.replace(seen, in: directory)
    return counts
  }

  /// `nil` for a binary or empty file. `memchr`, where a Swift loop over the
  /// bytes measured half the speed.
  private static func lines(in data: Data) -> Int? {
    data.withUnsafeBytes { buffer in
      guard let base = buffer.baseAddress, !buffer.isEmpty else { return nil }
      guard memchr(base, 0, min(buffer.count, 8000)) == nil else { return nil }
      let newline = Int32(UInt8(ascii: "\n"))
      var count = 0
      var offset = 0
      while offset < buffer.count,
        let found = memchr(base + offset, newline, buffer.count - offset)
      {
        count += 1
        offset = base.distance(to: UnsafeRawPointer(found)) + 1
      }
      return buffer[buffer.count - 1] == UInt8(ascii: "\n") ? count : count + 1
    }
  }
}
