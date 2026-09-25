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
          Text(
            row.isInstalled
              ? t("agents.hooks-installed-in", row.displayPath) : t("agents.not-installed")
          )
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
          if row.isInstalled {
            if row.wantsUpdate {
              Button(t("action.update")) { model.installAgentHooks(row.id) }
            }
            Button(t("action.remove")) { model.removeAgentHooks(row.id) }
          } else {
            Button(t("action.add")) { model.installAgentHooks(row.id) }
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
        Text(model.agentHooksSnippet(row.id))
          .font(.system(size: 10, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(height: 240)
    }
    .padding(12)
    .frame(width: 420)
  }
}
