import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Agents: the preferred agent, or the hooks, a row per agent found,
/// apart as they grow with each agent. None is recommended or installed here.
struct AgentsSettingsPage: View {
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

  init(model: AppModel, part: Part = .agent) {
    self.model = model
    _part = State(initialValue: part)
  }

  var body: some View {
    Form {
      PartPicker(label: t("label.agents"), selection: $part, title: \.title)

      switch part {
      case .agent: agentSection
      case .hooks:
        if !model.agentHooksRows.isEmpty {
          AgentHooksSection(model: model)
        }
        commandLineToolSection
      }
    }
    .formStyle(.grouped)
    .onAppear { model.refreshInstallState() }
  }

  private var agentSection: some View {
    Section {
      DetectionPicker(
        label: t("agents.preferred-agent"),
        selection: model.setting(
          \.preferredAgentID, or: AgentCatalogue.noneID, write: model.setPreferredAgent),
        options: model.agentDetection.options(selected:),
        rescanning: model,
        info: model.agentPathNote
      )
      if model.usesCustomAgent {
        CustomCommandRow(
          label: t("label.command"), info: t("agents.command-info"),
          prompt: t("agents.command-prompt"),
          text: model.setting(\.customAgentCommand, write: model.setCustomAgentCommand))
      } else if let agentID = model.workspace.preferredAgentID, agentID != AgentCatalogue.noneID {
        InfoLabeledContent(t("agents.flags"), info: t("agents.flags-info")) {
          // No prompt text: a greyed example in an empty field reads as a
          // default the agent is already being started with.
          TextField(t("agents.flags"), text: model.agentFlagsSetting(for: agentID))
        }
      }
      InfoToggle(
        t("agents.auto-start-tab"), info: t("agents.auto-start-tab-info"),
        isOn: model.setting(\.autoStartAgent, write: model.setAutoStartAgent)
      )
      .disabled(!model.hasPreferredAgent)
      InfoToggle(
        t("agents.auto-start-create"), info: t("agents.auto-start-create-info"),
        isOn: model.setting(\.autoStartAgentOnCreate, write: model.setAutoStartAgentOnCreate)
      )
      .disabled(!model.hasPreferredAgent)
    }
  }

  private var commandLineToolSection: some View {
    Section(t("agents.command-line-tool")) {
      InfoLabeledContent(t("agents.helper-label"), info: t("agents.helper-info")) {
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
}
