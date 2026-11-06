import SwiftUI

/// Text cut at its head that draws whole, or a tail at least `leastWidth`
/// wide, or nothing; see Docs/design/appearance/window-chrome.md. Font and colour are the caller's.
struct ReadableTail: View {
  let text: String
  let leastWidth: Double
  /// Room around the text, kept only while some of it is drawn, so a caller's
  /// gap goes with it.
  var insets = EdgeInsets()

  var body: some View {
    ViewThatFits(in: .horizontal) {
      label
      label.frame(minWidth: leastWidth, idealWidth: leastWidth, alignment: .leading)
      Color.clear.frame(width: 0, height: 0)
    }
  }

  private var label: some View {
    Text(text)
      .lineLimit(1)
      .truncationMode(.head)
      .padding(insets)
  }
}
