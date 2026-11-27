import SwiftUI

/// A line under a keys cell: why keys were refused, a warning, or the recording hint.
struct KeysNote: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.system(size: UIMetrics.settingsSmallTextSize))
      .foregroundStyle(color)
      .fixedSize(horizontal: false, vertical: true)
  }
}
