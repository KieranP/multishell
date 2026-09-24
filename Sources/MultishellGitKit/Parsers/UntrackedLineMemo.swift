import Foundation

/// Each untracked file's count by size and date, so an unmoved tree is stat'ed
/// rather than read; per worktree, only the files the last count saw.
final class UntrackedLineMemo: @unchecked Sendable {
  struct Entry: Sendable {
    let size: Int
    let modified: Date
    /// `nil` for a file with no line to show: binary or empty.
    let lines: Int?
  }

  private let lock = NSLock()
  private var byDirectory: [String: [String: Entry]] = [:]

  func entries(in directory: URL) -> [String: Entry] {
    lock.withLock { byDirectory[directory.path] ?? [:] }
  }

  func replace(_ entries: [String: Entry], in directory: URL) {
    lock.withLock { byDirectory[directory.path] = entries }
  }

  func forget(directories: some Sequence<String>) {
    lock.withLock { for directory in directories { byDirectory[directory] = nil } }
  }
}
