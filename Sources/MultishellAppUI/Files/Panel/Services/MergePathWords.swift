import MultishellCore
import SwiftUI

/// A merge path stop's words: its title, or the checks step's disclosure
/// around it, over its hint, which VoiceOver reads as one element.
struct MergePathWords<Heading: View>: View {
  private static var lineSpacing: Double { 1 }

  let hint: String?
  let metrics: UIMetrics
  let theme: Theme
  @ViewBuilder let heading: Heading

  var body: some View {
    VStack(alignment: .leading, spacing: Self.lineSpacing) {
      heading
      if let hint {
        Text(hint)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.filesPanel.text)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
