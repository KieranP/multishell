import Foundation

/// Ghostty config as it reads in a file, one `key = value` line per setting in
/// the order set, a later line overriding an earlier one or, for a list key, adding to it.
struct GhosttyConfigText {
  private var lines: [String] = []

  init(_ build: (inout GhosttyConfigText) -> Void = { _ in }) {
    build(&self)
  }

  var rendered: String { lines.joined(separator: "\n") }

  /// A theme file's colour reaches here unchecked, and a line break in it
  /// would add a line the allow-list never saw, so such a value is left out.
  mutating func set(_ key: String, _ value: String) {
    guard !value.contains(where: \.isNewline) else { return }
    lines.append("\(key) = \(value)")
  }

  /// Ghostty parses a number with Zig's `parseFloat`, which takes a `.` and
  /// ASCII digits only, so the locale must not format it.
  mutating func set(_ key: String, _ value: Double) {
    let style = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US_POSIX"))
      .precision(.fractionLength(0...2)).grouping(.never)
    set(key, value.formatted(style))
  }
}
