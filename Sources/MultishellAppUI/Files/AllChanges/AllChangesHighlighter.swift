import MultishellAppCore
import MultishellCore
import MultishellHighlight

/// Colours one of the All changes tab's texts, Unified's or a split side, a
/// file at a time and only the files near the clip, each parsed over its own
/// rows and kept by path, so a fold opening or a scroll back parses nothing again.
@MainActor
final class AllChangesHighlighter {
  /// Split's left side for the committed side, else Unified's or the right.
  private let side: DiffSide?
  private var spansByPath: [String: (text: DiffDisplayText, spans: [HighlightSpan])] = [:]

  init(side: DiffSide? = nil) {
    self.side = side
  }

  /// The parses' time and the apply's, which pace the tab's re-reads, or `nil`
  /// if stopped.
  func highlight(
    _ document: AllChangesDocument,
    sections shown: ClosedRange<Int>,
    theme: Theme,
    on textView: () -> DiffTextView?,
  ) async -> Duration? {
    let started = ContinuousClock.now
    var runs: [HighlightSpan] = []
    for index in shown where document.sections.indices.contains(index) {
      let section = document.sections[index]
      guard let fileText = section.sideText(on: side), !section.rows.isEmpty else { continue }
      let spans: [HighlightSpan]
      if let cached = spansByPath[section.path], cached.text == fileText {
        spans = cached.spans
      } else {
        spans = await DiffHighlighting.spans(for: fileText, path: section.path)
        guard !Task.isCancelled else { return nil }
        spansByPath[section.path] = (fileText, spans)
      }
      runs += document.documentSpans(spans, ofSection: index, side: side)
    }
    let listed = Set(document.sections.map(\.path))
    spansByPath = spansByPath.filter { listed.contains($0.key) }
    let parse = started.duration(to: .now)
    let text = side == .committed ? document.committedText ?? document.text : document.text
    guard let applied = await textView()?.applyHighlights(runs, for: text, theme: theme)
    else { return nil }
    return parse + applied
  }
}
