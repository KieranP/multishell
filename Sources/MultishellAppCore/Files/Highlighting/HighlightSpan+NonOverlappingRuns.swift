extension HighlightSpan {
  /// Runs in text order that do not overlap, a later span winning as applied in turn,
  /// and a plain span clearing but leaving no run. Why each: Docs/design/files.md.
  public static func nonOverlappingRuns(_ spans: [Self], length: Int) -> [Self] {
    var roles = [HighlightRole?](repeating: nil, count: length)
    for span in spans {
      for unit in span.range.clamped(to: 0..<length) { roles[unit] = span.role }
    }
    var runs: [Self] = []
    var start = 0
    while start < length {
      guard let role = roles[start] else {
        start += 1
        continue
      }
      var end = start + 1
      while end < length, roles[end] == role { end += 1 }
      if role != .plain { runs.append(Self(range: start..<end, role: role)) }
      start = end
    }
    return runs
  }
}
