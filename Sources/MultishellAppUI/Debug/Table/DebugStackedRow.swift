import MultishellCore
import SwiftUI

/// A debug table row where the panel is too narrow for its columns: its name
/// and headline number on one line, what the columns held in captions below.
struct DebugStackedRow<Title: View, Headline: View>: View {
  let captions: [String]
  let theme: Theme
  let metrics: UIMetrics
  @ViewBuilder let title: Title
  @ViewBuilder let headline: Headline

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
        title.frame(maxWidth: .infinity, alignment: .leading)
        headline
      }
      ForEach(captions, id: \.self) { caption in
        Text(caption)
          .font(.system(size: metrics.caption))
          .monospacedDigit()
          .foregroundStyle(theme.textSecondary)
      }
    }
  }
}
