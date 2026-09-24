import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Agents: the preferred agent, or the hooks, a row per agent found,
/// apart as they grow with each agent. None is recommended or installed here.
struct AgentSettingsTab: View {
  enum Part: CaseIterable {
    case agent
    case hooks

    var title: String {
      switch self {
      case .agent: t("agents.part-agent")
      case .hooks: t("settings.hooks")
      }
    }
  }

  let model: AppModel

  @State private var part: Part
  /// Which row's file is on show, at most one at a time.
  @State private var shownContents: String?

  init(model: AppModel, part: Part = .agent) {
    self.model = model
    _part = State(initialValue: part)
  }

  var body: some View {
    Form {
      Section {
        Picker(t("label.agents"), selection: $part) {
          ForEach(Part.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      switch part {
      case .agent: agentSection
      case .hooks:
        if !model.agentHooksRows.isEmpty {
          hooksSection
        }
        commandLineToolSection
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshAgentStatus() }
  }

  private var agentSection: some View {
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
  }

  private var commandLineToolSection: some View {
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
            if row.wantsUpdate {
              Button(t("action.update")) { model.installAgentHooks(row.id) }
            }
            Button(t("action.remove")) { model.removeAgentHooks(row.id) }
          } else {
            Button(t("action.add")) { model.installAgentHooks(row.id) }
          }
          // A popover, not the page: shown inline it added 166 pt a row.
          Button(t("agents.show", row.contentsName)) { shownContents = row.id }
            .popover(isPresented: isShowing(row), arrowEdge: .bottom) { contents(of: row) }
        }
        .controlSize(.small)
      }
    }
  }

  private func isShowing(_ row: AgentHooksRow) -> Binding<Bool> {
    Binding(
      get: { shownContents == row.id },
      set: { if !$0, shownContents == row.id { shownContents = nil } })
  }

  private func contents(of row: AgentHooksRow) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(row.path)
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
