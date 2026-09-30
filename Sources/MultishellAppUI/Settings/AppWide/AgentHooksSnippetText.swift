import SwiftUI

/// An agent's hooks file as the popover shows it, selectable and monospaced.
struct AgentHooksSnippetText: View {
  let snippet: String

  var body: some View {
    Text(snippet)
      .font(.system(size: 10, design: .monospaced))
      // The popover inherits the form row's trailing alignment, which hid the indent.
      .multilineTextAlignment(.leading)
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
