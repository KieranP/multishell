import SwiftUI

/// The text field a picker's Custom choice opens beneath it: an agent's or
/// editor's command, or a shell's path.
struct CustomCommandRow: View {
  let label: String
  let info: String
  let prompt: String
  @Binding var text: String

  var body: some View {
    InfoLabeledContent(label, info: info) {
      TextField(label, text: $text, prompt: Text(prompt))
    }
  }
}
