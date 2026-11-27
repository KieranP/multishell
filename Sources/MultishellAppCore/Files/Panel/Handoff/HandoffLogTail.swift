import Foundation

/// The end of a log or report as Send quotes it: where it failed is at the end,
/// and an agent's context is not the place for a whole build log.
enum HandoffLogTail {
  private static let lineCount = 80
  /// What a read keeps for the tail to cut: blank and marker lines at the end go.
  static var linesToRead: Int { lineCount * 2 }

  /// Its last lines, said so where some were cut.
  static func lines(of text: String) -> (lines: [String], cutCount: Int) {
    // A bare "\r" is a progress bar's frame, not a line.
    let all = text.lines().map(String.init)
    let trimmed = Array(
      all.reversed().drop { $0.trimmingCharacters(in: .whitespaces).isEmpty }.reversed()
    )
    let kept = trimmed.suffix(lineCount)
    return (Array(kept), trimmed.count - kept.count)
  }
}
