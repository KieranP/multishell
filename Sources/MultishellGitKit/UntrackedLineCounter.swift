import Foundation

/// Lines in the files git lists as untracked, which have no diff until they
/// are added; see docs/design/worktrees.md.
enum UntrackedLineCounter {
  /// A poll's share of the disk: how many files it opens, how big one may be,
  /// and how much it reads in all before it stops counting.
  static let fileLimit = 500
  static let byteLimit = 1 << 20
  static let totalByteLimit = 8 << 20

  /// `unscored` is the files with no line to show: binary, empty, or unread.
  /// Never one past `fileLimit`, which is not counted; see worktrees.md.
  static func count(paths: [String], in directory: URL) -> (lines: Int, unscored: Int) {
    var lines = 0
    var unscored = 0
    var read = 0
    for path in paths.prefix(fileLimit) {
      let url = directory.appendingPathComponent(path)
      // A symlink is not a regular file, so it is never read: its own size
      // is not its target's and the read would follow it.
      guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
        values.isRegularFile == true, let size = values.fileSize, size <= byteLimit,
        read + size <= totalByteLimit, let data = try? Data(contentsOf: url)
      else {
        unscored += 1
        continue
      }
      read += data.count
      guard !data.prefix(8000).contains(0), let last = data.last else {
        unscored += 1
        continue
      }
      lines += data.count(where: { $0 == UInt8(ascii: "\n") })
      if last != UInt8(ascii: "\n") { lines += 1 }
    }
    return (lines, unscored)
  }

  /// `git ls-files --others -z` writes one NUL-terminated path a file. Only
  /// the paths that will be read become strings; see worktrees.md.
  static func paths(from output: String) -> [String] {
    output.split(separator: "\0", omittingEmptySubsequences: true)
      .prefix(fileLimit).map(String.init)
  }
}
