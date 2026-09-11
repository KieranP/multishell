import SwiftUI

/// A form row with its (i) right after the label, in the form's label
/// column; the control keeps the content column to itself. Wrapping a
/// labelled control in a plain `HStack` would pull its label out of that
/// column.
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
