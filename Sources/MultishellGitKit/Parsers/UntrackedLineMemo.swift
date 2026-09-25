import Foundation
import Synchronization

/// Each untracked file's count by size and date, so an unmoved tree is stat'ed
/// rather than read; per worktree, only the files the last count saw.
final class UntrackedLineMemo: Sendable {
  struct Entry: Sendable {
    let size: Int
    let modified: Date
    /// `nil` for a file with no line to show: binary or empty.
    let lines: Int?
  }

  private let byDirectory = Mutex<[String: [String: Entry]]>([:])

  func entries(in directory: URL) -> [String: Entry] {
    byDirectory.withLock { $0[directory.path] ?? [:] }
  }

  func replace(_ entries: [String: Entry], in directory: URL) {
    byDirectory.withLock { $0[directory.path] = entries }
  }

  func forget(directories: some Sequence<String>) {
    byDirectory.withLock { for directory in directories { $0[directory] = nil } }
  }
}
