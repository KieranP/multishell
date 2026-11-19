import Foundation

/// A job's log from the Actions REST endpoint as an agent reads it: each line
/// starts with a timestamp and may carry colour, and the runner's cleanup follows the failure.
enum GitHubJobLog {
  private static let newline = UInt8(ascii: "\n")
  private static let errorMarker = Array("##[error]".utf8)

  /// Only its last `lineLimit` lines up to the last `##[error]` are cleaned, a line
  /// ending at `\n` alone; why in services/send-feedback.md.
  static func log(from output: String, keepingLast lineLimit: Int) -> FailedCheckLog {
    // A step's first line opens with a byte-order mark before its timestamp.
    let timestamp = /^\x{FEFF}?\d{4}-\d\d-\d\dT[0-9:.]+Z ?/
    let controlCode = /\x1b\[[0-9;?]*[A-Za-z]/
    let groupStart = /^##\[group\]/
    let failure = Substring(output.utf8[..<endOfLastErrorLine(in: output.utf8)])
    let kept = tail(of: failure, lineLimit: lineLimit)
    // Counted in bytes, which costs no string per line.
    let lineCount = failure.utf8.count { $0 == newline } + 1
    let cleaned = kept.compactMap { line -> String? in
      let message = line.replacing(timestamp, with: "").replacing(controlCode, with: "")
      // A fold's end says nothing; its start names the step. `##[error]` stays.
      if message == "##[endgroup]" { return nil }
      return message.replacing(groupStart, with: "")
    }
    // A fold end dropped from the tail is a line cut, so the count is the whole log's.
    return FailedCheckLog(
      text: cleaned.joined(separator: "\n"),
      earlierLineCount: max(0, lineCount - cleaned.count),
    )
  }

  /// Where the last line naming `##[error]` ends, or the log's end where none
  /// does. Found walking back, as the post-job steps after it are few.
  private static func endOfLastErrorLine(in bytes: String.UTF8View) -> String.Index {
    var index = bytes.endIndex
    var lineEnd = bytes.endIndex
    while index > bytes.startIndex {
      let previous = bytes.index(before: index)
      if bytes[previous] == newline {
        lineEnd = previous
      } else if bytes[previous...].starts(with: errorMarker) {
        return lineEnd
      }
      index = previous
    }
    return bytes.endIndex
  }

  /// Its last `lineLimit` lines, `\r\n` ends trimmed, found walking back through the
  /// bytes: splitting the whole log first costs as many strings as it has lines.
  private static func tail(of output: Substring, lineLimit: Int) -> [String] {
    let bytes = output.utf8
    var start = bytes.endIndex
    var newlines = 0
    while start > bytes.startIndex {
      let previous = bytes.index(before: start)
      if bytes[previous] == newline {
        newlines += 1
        if newlines == lineLimit { break }
      }
      start = previous
    }
    return bytes[start...].split(separator: newline, omittingEmptySubsequences: false).map { line in
      let text = String(decoding: line, as: UTF8.self)
      return text.hasSuffix("\r") ? String(text.dropLast()) : text
    }
  }
}
