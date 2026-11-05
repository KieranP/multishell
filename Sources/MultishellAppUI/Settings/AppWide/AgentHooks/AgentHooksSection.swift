import MultishellAppCore
import SwiftUI

/// Settings > Agents > Hooks: a row per agent found, each with its file shown
/// in a popover on request.
struct AgentHooksSection: View {
  let model: AppModel

  /// Which row's file is on show, at most one at a time.
  @State private var shownSnippetRowID: String?

  var body: some View {
    SettingsGroup(t("agents.hooks-section")) {
      ForEach(model.agentHooksRows) { row in
        // Not a labeled row, whose control side stops at a field's width: the
        // path takes all the room its buttons leave.
        HStack(spacing: UIMetrics.settingsRowSpacing) {
          InfoLabel(t("agents.row-label", row.name), info: row.info)
            .fixedSize()
          HStack(spacing: UIMetrics.settingsControlSpacing) {
            Text(row.statusLabel)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.head)
              .frame(maxWidth: .infinity, alignment: .trailing)
            ForEach(row.actions, id: \.self) { action in
              actionButton(action, for: row)
            }
            // A popover, not the page: shown inline it added 166 pt a row.
            Button(t("agents.show", row.contentsLabel)) { shownSnippetRowID = row.id }
              .popover(isPresented: snippetPresented(for: row), arrowEdge: .bottom) {
                AgentHooksSnippetPopover(model: model, row: row)
              }
          }
        }
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
      set: { if !$0, shownSnippetRowID == row.id { shownSnippetRowID = nil } },
    )
  }
}
