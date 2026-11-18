import MultishellCore

/// An All changes tab's last read, runtime only: every listed file in the
/// Changes list's order.
struct AllChangesReading: Equatable, Sendable {
  /// The list the read was given, so a status read listing the same reads nothing.
  let listed: [AllChangesFileChange]
  let files: [AllChangesFile]
  /// The base the files were diffed against, Branch's; `nil` under Modified.
  let baseName: String?
  /// Each file's place in `files`: the view asks after files by path as it scrolls.
  private let indexByPath: [String: Int]

  /// What the bar counts: every file's rows, or the list's count where none.
  var lineCounts: FileLineCounts {
    files.reduce(FileLineCounts(insertions: 0, deletions: 0)) { total, file in
      file.lineCounts.map { total + $0 } ?? total
    }
  }

  init(listed: [AllChangesFileChange], files: [AllChangesFile], baseName: String? = nil) {
    self.listed = listed
    self.files = files
    self.baseName = baseName
    indexByPath = Dictionary(keepingFirst: files.enumerated().map { ($1.path, $0) })
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.listed == rhs.listed && lhs.files == rhs.files && lhs.baseName == rhs.baseName
  }

  func file(at path: String) -> AllChangesFile? {
    indexByPath[path].map { files[$0] }
  }

  /// Whether `path` waits unread, away from the screen when the read ran.
  func isUnread(_ path: String) -> Bool {
    file(at: path)?.content == .unread
  }

  /// Whether `path` is owed a read once near the screen: unread, or its rows stale.
  func owesRead(_ path: String) -> Bool {
    guard let file = file(at: path) else { return false }
    return file.isStale || file.content == .unread
  }
}
