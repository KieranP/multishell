import MultishellAppCore
import MultishellCore
import SwiftUI

/// All Projects > Agents > Agent settings: the preferred agent, its flags and
/// when it starts, and Auto Rename. None is recommended or installed here.
struct AppAgentSettingsPage: View {
  let model: AppModel

  var body: some View {
    SettingsForm {
      agentSection
      AutoRenameSection(model: model)
    }
  }

  private var agentSection: some View {
    SettingsGroup(t("agents.section-preferred")) {
      DetectionPicker(
        label: t("agents.preferred-agent"),
        selection: model.preferredAgentBinding,
        options: model.agentDetection.options(selected:),
        refreshing: model,
        info: model.agentPathInfo,
      )
      if model.usesCustomAgent {
        CustomChoiceField(
          label: t("label.command"),
          info: t("agents.command-info"),
          prompt: t("agents.command-prompt"),
          text: model.settingBinding(\.customAgentCommand, write: model.setCustomAgentCommand),
        )
      } else {
        InfoLabeledContent(t("agents.flags"), info: t("agents.flags-info")) {
          // No prompt text: a greyed example in an empty field reads as a
          // default the agent is already being started with.
          TextField(
            t("agents.flags"),
            text: model.agentFlagsBinding(for: model.globalAgentID),
            prompt: Text(verbatim: ""),
          )
          .font(.system(size: UIMetrics.settingsMonospacedFieldSize, design: .monospaced))
          .disabled(!model.hasPreferredAgent)
        }
      }
      InfoToggle(
        t("agents.auto-start-tab"),
        info: t("agents.auto-start-tab-info"),
        isOn: model.settingBinding(\.autoStartsAgent, write: model.setAutoStartsAgent),
      )
      .disabled(!model.hasPreferredAgent)
      InfoToggle(
        t("agents.auto-start-create"),
        info: t("agents.auto-start-create-info"),
        isOn: model.settingBinding(
          \.autoStartsAgentOnCreate,
          write: model.setAutoStartsAgentOnCreate,
        ),
      )
      .disabled(!model.hasPreferredAgent)
    }
  }
}
