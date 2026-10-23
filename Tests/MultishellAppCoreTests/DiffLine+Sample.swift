@testable import MultishellAppCore

/// Rows numbered by `HEAD` alone, which is all a change anchor reads.
extension DiffLine {
  /// `count` lines a commit put at the top of `HEAD`, unchanged since.
  static func committedAbove(_ count: Int) -> [DiffLine] {
    (0..<count).map { index in
      DiffLine(kind: .context, oldNumber: index + 1, newNumber: nil, text: "commit \(index)")
    }
  }

  static func unchanged(_ line: Int) -> DiffLine {
    DiffLine(kind: .context, oldNumber: line, newNumber: nil, text: "\(line)")
  }

  /// Each line removed, then the same lines with an `x` added in their place.
  static func replaced(_ lines: ClosedRange<Int>) -> [DiffLine] {
    lines.map { DiffLine(kind: .removed, oldNumber: $0, newNumber: nil, text: "\($0)") }
      + lines.map { DiffLine(kind: .added, oldNumber: nil, newNumber: nil, text: "\($0)x") }
  }
}
