import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Agents: the preferred agent, and the hooks that feed the
/// state dots, one row per agent this machine has.
///
/// What detection found and nothing else. No agent is named here, none is
/// recommended, and none is offered an installer: a machine with none
/// installed gets an empty picker, which says the same thing without
/// pointing anywhere.
struct AgentSettingsTab: View {
  let model: AppModel

  /// Which row's file is on show, at most one at a time.
  @State private var shownContents: String?

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: t("agents.preferred-agent"),
          selection: model.setting(
            \.preferredAgentID, or: AgentCatalogue.noneID, write: model.setPreferredAgent),
          options: model.agentDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: environmentCaption
        )
        if model.workspace.preferredAgentID == AgentCatalogue.customID {
          InfoRow(t("agents.command"), info: t("agents.command-info")) {
            TextField(
              t("agents.command"),
              text: model.setting(\.customAgentCommand, write: model.setCustomAgentCommand),
              prompt: Text(t("agents.command-prompt")))
          }
        } else if let agentID = model.workspace.preferredAgentID, agentID != AgentCatalogue.noneID {
          InfoRow(t("agents.flags"), info: t("agents.flags-info")) {
            // No prompt text: a greyed example in an empty field reads as a
            // default the agent is already being started with.
            TextField(t("agents.flags"), text: model.agentFlagsSetting(for: agentID))
          }
        }
        InfoToggle(
          t("agents.auto-start-tab"), info: t("agents.auto-start-tab-info"),
          isOn: model.setting(\.autoStartAgent, write: model.setAutoStartAgent)
        )
        .disabled(model.workspace.preferredAgentID == nil)
        InfoToggle(
          t("agents.auto-start-create"), info: t("agents.auto-start-create-info"),
          isOn: model.setting(\.autoStartAgentOnCreate, write: model.setAutoStartAgentOnCreate)
        )
        .disabled(model.workspace.preferredAgentID == nil)
      }

      if !model.agentHooksRows.isEmpty {
        hooksSection
      }

      Section(t("agents.command-line-tool")) {
        InfoRow(t("agents.helper-label"), info: t("agents.helper-info")) {
          Text(
            model.commandLineToolInstalled
              ? t("agents.helper-installed") : t("agents.not-installed")
          )
          .foregroundStyle(.secondary)
          if !model.commandLineToolInstalled {
            Button(t("agents.install-helper")) { model.installCommandLineTool() }
              .controlSize(.small)
          }
        }
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshAgentStatus() }
  }

  private var hooksSection: some View {
    Section(t("agents.hooks-section")) {
      ForEach(model.agentHooksRows) { row in
        InfoRow(t("agents.row-label", row.name), info: row.info) {
          Text(
            row.isInstalled
              ? t("agents.hooks-installed-in", row.path) : t("agents.not-installed")
          )
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
          if row.isInstalled {
            Button(t("action.remove")) { model.removeAgentHooks(row.id) }
          } else {
            Button(t("action.add")) { model.installAgentHooks(row.id) }
          }
          Button(
            shownContents == row.id
              ? t("agents.hide", row.contentsName)
              : t("agents.show", row.contentsName)
          ) {
            shownContents = shownContents == row.id ? nil : row.id
          }
        }
        .controlSize(.small)
        if shownContents == row.id {
          contents(of: row)
        }
      }
    }
  }

  private func contents(of row: AgentHooksRow) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      ScrollView(.vertical) {
        Text(model.agentHooksSnippet(row.id))
          .font(.system(size: 10, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(height: 140)
      Button(t("action.copy")) { model.copyToClipboard(model.agentHooksSnippet(row.id)) }
        .controlSize(.small)
    }
  }

  private var environmentCaption: String {
    switch model.loginEnvironment?.source {
    case nil:
      return t("agents.path-asking")
    case .loginShell(let shell):
      return t("agents.path-from-login-shell", shell.path)
    case .processFallback(let reason):
      return t("agents.path-fallback", reason)
    }
  }
}
