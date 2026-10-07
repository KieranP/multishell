import MultishellAppCore
import SwiftUI

/// An agent's hooks file on request: where it goes, a Copy button and the
/// lines themselves.
struct AgentHooksSnippetPopover: View {
  let model: AppModel
  let row: AgentHooksRow

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(row.displayPath)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
        Spacer(minLength: 8)
        Button(t("action.copy")) { model.copyToClipboard(model.agentHooksSnippet(row.id)) }
          .controlSize(.small)
      }
      ScrollView(.vertical) {
        AgentHooksSnippetText(snippet: model.agentHooksSnippet(row.id))
      }
      .frame(height: 240)
    }
    .padding(12)
    .frame(width: 420)
  }
}
