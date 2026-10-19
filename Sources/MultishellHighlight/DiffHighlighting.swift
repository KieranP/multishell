import MultishellAppCore
import MultishellCore

/// A file tab's highlighting: each side worth parsing parsed apart, off the
/// main actor, and its spans mapped onto the rows it colours, in text order.
public enum DiffHighlighting {
  /// Past the size cap nothing is highlighted, the tab showing a notice.
  public static func spans(
    for text: DiffDisplayText,
    path: String,
  ) async -> [HighlightSpan] {
    // The file's own line 1, which a unified diff lists after `HEAD`'s; a
    // split's left side and a deleted file have only `HEAD`'s.
    let firstLine =
      (text.lines.first { $0.newNumber == 1 } ?? text.lines.first { $0.oldNumber == 1 })?
      .text
    guard let language = HighlightLanguage.language(forPath: path, firstLine: firstLine) else {
      return []
    }
    return await runOnDispatch {
      var cache = HighlightPassCache()
      var spans: [HighlightSpan] = []
      for side in DiffSideSpans.parsedSides(of: text) {
        let sideText = DiffSideText(of: text, side: side)
        guard !sideText.string.isEmpty else { continue }
        let sideSpans = SyntaxHighlighter.shared.spans(
          in: sideText.string,
          language: language,
          cache: &cache,
          within: DiffSideSpans.keptRanges(of: sideText),
        )
        spans += DiffSideSpans.mapped(sideSpans, from: sideText)
      }
      return HighlightSpan.nonOverlappingRuns(spans, length: text.string.utf16.count)
    }
  }
}
