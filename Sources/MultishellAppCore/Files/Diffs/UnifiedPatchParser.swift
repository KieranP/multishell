import Foundation

/// Parses one file's `git diff -p --unified=<every line>`, decoding each line
/// in the file's own encoding: git copies the file's bytes into the patch.
enum UnifiedPatchParser {
  private static let newline = UInt8(ascii: "\n")
  private static let carriageReturn = UInt8(ascii: "\r")
  private static let sectionHeader = Array("diff --git ".utf8)

  static func parse(_ patch: Data, encoding: String.Encoding) -> ParsedPatch {
    guard !patch.isEmpty else { return .unchanged }
    var lines: [DiffLine] = []
    var inHunk = false
    var hasModeChange = false
    var oldNumber = 0
    var newNumber = 0
    for raw in patch.split(separator: newline, omittingEmptySubsequences: false) {
      guard inHunk else {
        let header = String(decoding: raw, as: UTF8.self)
        if header.hasPrefix("Binary files ") || header == "GIT binary patch" { return .binary }
        if header.hasPrefix("old mode ") { hasModeChange = true }
        if let start = hunkStart(header) {
          (oldNumber, newNumber) = start
          inHunk = true
        }
        continue
      }
      // A type change, a file swapped for a symlink, prints a second section.
      if raw.starts(with: Self.sectionHeader) {
        inHunk = false
        continue
      }
      guard let marker = raw.first else { continue }
      let text = decode(raw.dropFirst(), encoding: encoding)
      switch marker {
      case UInt8(ascii: " "):
        lines.append(
          DiffLine(kind: .context, oldNumber: oldNumber, newNumber: newNumber, text: text)
        )
        oldNumber += 1
        newNumber += 1

      case UInt8(ascii: "-"):
        lines.append(DiffLine(kind: .removed, oldNumber: oldNumber, newNumber: nil, text: text))
        oldNumber += 1

      case UInt8(ascii: "+"):
        lines.append(DiffLine(kind: .added, oldNumber: nil, newNumber: newNumber, text: text))
        newNumber += 1

      default:
        // `\ No newline at end of file`, or the next hunk's header.
        if let start = hunkStart(String(decoding: raw, as: UTF8.self)) {
          (oldNumber, newNumber) = start
        }
      }
    }
    if lines.isEmpty { return hasModeChange ? .modeOnly : .unchanged }
    return .lines(lines)
  }

  /// `@@ -1,3 +1,4 @@`, or `-0,0` for a side that is empty, where the first
  /// line is still numbered one.
  private static func hunkStart(_ header: String) -> (old: Int, new: Int)? {
    guard header.hasPrefix("@@ -") else { return nil }
    let fields = header.dropFirst(4).split(separator: " ")
    guard fields.count >= 2, fields[1].hasPrefix("+"),
      let old = Int(fields[0].split(separator: ",")[0]),
      let new = Int(fields[1].dropFirst().split(separator: ",")[0])
    else { return nil }
    return (max(old, 1), max(new, 1))
  }

  /// CRLF loses its `\r` for display.
  private static func decode(_ bytes: Data.SubSequence, encoding: String.Encoding) -> String {
    let line = bytes.last == carriageReturn ? bytes.dropLast() : bytes
    return String(data: Data(line), encoding: encoding) ?? String(decoding: line, as: UTF8.self)
  }
}
