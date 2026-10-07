import Foundation

/// Reads the environment a shell prints with `env -0`, past whatever its rc
/// files greeted with.
enum EnvironmentDumpParser {
  /// Printed on a line of its own before `env -0`, after any greeting the rc
  /// files wrote: a greeting shaped like `KEY=` was taken for a variable.
  static let startMarker = "__multishell_env__"

  /// `env -0` output, from the line after the marker. Without one, an entry
  /// begins at the first line reading `KEY=`, which a greeting can fool.
  static func parse(nulSeparated text: String) -> [String: String] {
    let marked = text.range(of: "\n\(startMarker)\n").map { text[$0.upperBound...] }
    var variables: [String: String] = [:]
    for whole in (marked ?? text[...]).split(separator: "\0", omittingEmptySubsequences: true) {
      guard let entry = marked == nil ? entryAfterGreeting(whole) : whole,
        let equals = entry.firstIndex(of: "=")
      else {
        continue
      }
      variables[String(entry[..<equals])] = String(entry[entry.index(after: equals)...])
    }
    return variables
  }

  /// A greeting with no final newline is not told from the key it runs into.
  private static func entryAfterGreeting(_ entry: Substring) -> Substring? {
    var start = entry.startIndex
    while start < entry.endIndex {
      let rest = entry[start...]
      if let equals = rest.firstIndex(of: "=") {
        let key = rest[..<equals]
        if !key.isEmpty, !key.contains(where: { $0 == " " || $0 == "\n" }) { return rest }
      }
      guard let newline = rest.firstIndex(of: "\n") else { return nil }
      start = rest.index(after: newline)
    }
    return nil
  }
}
