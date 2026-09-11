import SwiftUI

/// A form row with its (i) after the label, in the form's label column: a
/// plain `HStack` would pull the label out of that column.
struct InfoRow<Content: View>: View {
  let label: String
  let info: String
  @ViewBuilder let content: () -> Content

  init(_ label: String, info: String, @ViewBuilder content: @escaping () -> Content) {
    self.label = label
    self.info = info
    self.content = content
  }

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) { content().labelsHidden() }
    } label: {
      InfoLabel(label, info: info)
    }
  }
}
