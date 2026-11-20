/// What find searched in a tab, kept across a change to carry its selection
/// by line: a file tab's text, or the All changes tab's files end to end.
enum SearchedLayout {
  case allChanges(AllChangesDocument)
  case fileText(DiffDisplayText)

  var text: DiffDisplayText {
    switch self {
    case .allChanges(let document): document.text
    case .fileText(let text): text
    }
  }

  /// Each file of the All changes tab is its own text view, which a range
  /// running on into the next file's would overrun.
  func isWithinOneFile(_ range: Range<Int>) -> Bool {
    switch self {
    case .allChanges(let document): document.isWithinOneFile(range)
    case .fileText: true
    }
  }

  func rangeOnSameLine(_ range: Range<Int>, from previous: Self) -> Range<Int>? {
    switch (self, previous) {
    case (.allChanges(let document), .allChanges(let previousDocument)):
      document.rangeOnSameLine(range, from: previousDocument)

    case (.fileText(let text), .fileText(let previousText)):
      text.rangeOnSameLine(range, from: previousText)

    case (.allChanges, .fileText), (.fileText, .allChanges):
      nil
    }
  }
}
