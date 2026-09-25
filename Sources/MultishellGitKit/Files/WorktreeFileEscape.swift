import Foundation
import MultishellCore

/// A listed path leading out of the repository or worktree, by `..` or a
/// symlinked folder. `LocalizedError`, to read as a sentence in the alert.
struct WorktreeFileEscape: LocalizedError {
  init() {}

  var errorDescription: String? {
    t("worktree-file.escape")
  }
}
