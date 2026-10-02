import MultishellAppCore
import SwiftUI

/// Settings > Agents > Hooks: a row per agent found, each with its file shown
/// in a popover on request.
struct AgentHooksSection: View {
  let model: AppModel

  /// Which row's file is on show, at most one at a time.
  @State private var shownSnippetRowID: String?

  var body: some View {
    Section(t("agents.hooks-section")) {
      ForEach(model.agentHooksRows) { row in
        InfoLabeledContent(t("agents.row-label", row.name), info: row.info) {
          Text(row.statusLabel)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
          ForEach(row.actions, id: \.self) { action in
            actionButton(action, for: row)
          }
          // A popover, not the page: shown inline it added 166 pt a row.
          Button(t("agents.show", row.contentsLabel)) { shownSnippetRowID = row.id }
            .popover(isPresented: snippetPresented(for: row), arrowEdge: .bottom) {
              snippetPopover(for: row)
            }
        }
        .controlSize(.small)
      }
    }
  }

  private func actionButton(_ action: AgentHooksRow.Action, for row: AgentHooksRow) -> some View {
    switch action {
    case .update: Button(t("action.update")) { model.installAgentHooks(row.id) }
    case .remove: Button(t("action.remove")) { model.removeAgentHooks(row.id) }
    case .add: Button(t("action.add")) { model.installAgentHooks(row.id) }
    }
  }

  private func snippetPresented(for row: AgentHooksRow) -> Binding<Bool> {
    Binding(
      get: { shownSnippetRowID == row.id },
      set: { if !$0, shownSnippetRowID == row.id { shownSnippetRowID = nil } })
  }

  private func snippetPopover(for row: AgentHooksRow) -> some View {
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
