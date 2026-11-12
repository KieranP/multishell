import MultishellCore

extension [DiffLine] {
  /// The side's text, line `n` at index `n - 1`: a file tab's rows hold every line.
  func text(on side: DiffSide) -> [String] {
    compactMap { side.shows($0.kind) ? $0.text : nil }
  }
}
