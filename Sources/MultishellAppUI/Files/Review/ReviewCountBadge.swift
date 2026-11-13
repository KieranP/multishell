import MultishellAppCore
import MultishellCore
import SwiftUI

/// A speech bubble and how many comments a file has waiting to be sent, on its
/// tab's title and its row in Files and Changes.
struct ReviewCountBadge: View {
  let count: Int
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let tint = Color(nsColor: theme.commentMark)
    HStack(spacing: 2) {
      SpeechBubbleShape()
        .fill(tint)
        .frame(width: metrics.badge, height: metrics.badge)
      Text("\(count)")
        .font(metrics.font(size: metrics.badge, weight: .semibold))
        .foregroundStyle(tint)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.pendingReviewComments(count))
  }
}
