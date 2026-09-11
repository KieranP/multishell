import SwiftUI

/// Label text with its (i) beside it.
struct InfoLabel: View {
  let text: String
  let info: String

  init(_ text: String, info: String) {
    self.text = text
    self.info = info
  }

  var body: some View {
    HStack(spacing: 4) {
      Text(text)
      InfoButton(info)
    }
  }
}
