import Foundation

/// The fixtures read as `git worktree list --porcelain` prints them, one
/// attribute per line; `-z` is the same with NUL where the newline was.
func zeroTerminated(_ text: String) -> String {
  text.replacingOccurrences(of: "\n", with: "\u{0}")
}
