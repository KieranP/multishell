import MultishellCore

extension ReviewComment {
  /// "Line 811", "Lines 58–61", "Removed line 806".
  public var lineLabel: String {
    let first = lines.lowerBound
    let last = lines.upperBound
    switch (side, first == last) {
    case (.onDisk, true): return t("review.line", first)
    case (.onDisk, false): return t("review.lines", first, last)
    case (.committed, true): return t("review.removed-line", first)
    case (.committed, false): return t("review.removed-lines", first, last)
    }
  }
}
