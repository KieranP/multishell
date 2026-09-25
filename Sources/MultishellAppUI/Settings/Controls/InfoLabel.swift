import SwiftUI

/// Label text with its (i) beside it.
struct InfoLabel: View {
  let text: String
  let info: String
  let spacing: CGFloat

  init(_ text: String, info: String, spacing: CGFloat = 4) {
    self.text = text
    self.info = info
    self.spacing = spacing
  }

  var body: some View {
    HStack(spacing: spacing) {
      Text(text)
      InfoButton(info)
    }
  }
}
