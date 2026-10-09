import MultishellAppCore
import SwiftUI

/// An agent's hooks file on request: where it goes, a Copy button and the
/// lines themselves.
struct AgentHooksSnippetPopover: View {
  let model: AppModel
  let row: AgentHooksRow

  var body: some View {
    let snippet = model.agentHooksSnippet(row.id)
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        PathText(row.displayPath)
        Spacer(minLength: 8)
        Button(t("action.copy")) { model.copyToClipboard(snippet) }
          .controlSize(.small)
      }
      ScrollView(.vertical) {
        AgentHooksSnippetText(snippet: snippet)
      }
      .frame(height: 240)
    }
    .padding(12)
    .frame(width: 420)
  }
}
