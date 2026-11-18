import MultishellAppCore
import MultishellCore

/// The parses of files the All changes list built, kept so a fold opening or
/// a scroll back parses nothing again; the oldest go past a cap.
struct AllChangesHighlightCache {
  /// Twice the files built and kept spare at once, so a short scroll back finds
  /// its parses; a whole file's spans run to megabytes.
  static let capacity = 64

  private var parses: [AllChangesHighlightKey: (text: DiffDisplayText, spans: [HighlightSpan])] =
    [:]
  /// Oldest first.
  private var order: [AllChangesHighlightKey] = []

  /// The spans parsed from `text`, where the file's rows are still those.
  func spans(of key: AllChangesHighlightKey, for text: DiffDisplayText) -> [HighlightSpan]? {
    parses[key].flatMap { $0.text == text ? $0.spans : nil }
  }

  mutating func keep(
    _ spans: [HighlightSpan],
    of key: AllChangesHighlightKey,
    for text: DiffDisplayText,
  ) {
    if parses.updateValue((text, spans), forKey: key) == nil { order.append(key) }
    while order.count > Self.capacity {
      parses[order.removeFirst()] = nil
    }
  }

  /// Drops each parse `isCurrent` turns down: one of a file gone, or of rows a
  /// read replaced, which would keep the old rows alive beside the new.
  mutating func keepOnly(where isCurrent: (AllChangesHighlightKey, DiffDisplayText) -> Bool) {
    parses = parses.filter { isCurrent($0.key, $0.value.text) }
    order.removeAll { parses[$0] == nil }
  }
}
