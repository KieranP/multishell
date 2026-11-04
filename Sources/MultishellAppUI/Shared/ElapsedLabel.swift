import SwiftUI

/// How long a pane has been in its state, in the one face a board card's corner
/// and a pane row's rail share.
struct ElapsedLabel: View {
  let text: String
  let color: Color
  let metrics: UIMetrics

  var body: some View {
    Text(text)
      .font(.system(size: metrics.badge, design: .monospaced))
      .monospacedDigit()
      .foregroundStyle(color)
  }
}
