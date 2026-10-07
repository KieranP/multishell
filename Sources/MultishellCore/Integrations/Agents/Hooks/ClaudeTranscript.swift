import Foundation

/// What Claude's transcript tells a hook; see Docs/design/agents.md.
enum ClaudeTranscript {
  /// Far more than a turn writes, and a read of a few milliseconds where a
  /// whole transcript runs to 23 MB.
  static let tailBytes = 4 << 20

  /// The last `tailBytes` of the file, `nil` where it cannot be read.
  static func tail(atPath path: String) -> (data: Data, startsAtFileStart: Bool)? {
    guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
    defer { try? handle.close() }
    guard let end = try? handle.seekToEnd() else { return nil }
    let start = end > UInt64(tailBytes) ? end - UInt64(tailBytes) : 0
    guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else {
      return nil
    }
    return (data, start == 0)
  }

  /// The tail's lines, less a first one the tail cut into.
  static func wholeLines(of data: Data, startsAtFileStart: Bool) -> ArraySlice<Data.SubSequence> {
    let lines = data.split(separator: UInt8(ascii: "\n"))
    return startsAtFileStart ? lines[...] : lines.dropFirst()
  }
}
