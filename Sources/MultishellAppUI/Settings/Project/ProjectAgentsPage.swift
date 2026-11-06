import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project's agent, its flags and when it starts, beside the global
/// choices it follows until overridden.
struct ProjectAgentsPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    SettingsForm {
      OverrideTable {
        OverrideRow(
          model: model,
          project: project,
          setting: \.preferredAgentID,
          label: t("project.preferred-agent"),
          info: t("project.preferred-agent-info"),
          options: model.agentDetection.options(selected:),
          globalValue: model.globalAgentValue,
          globalID: model.globalAgentID,
        )
        OverrideRow(
          model: model,
          project: project,
          setting: \.agentFlags,
          label: t("project.flags"),
          info: t("project.flags-info"),
          globalValue: model.globalAgentFlagsValue(for: project),
          fallback: model.workspace.globalAgentFlags(for: project),
          caption: nil,
        ) { flags in
          TextField(t("project.flags"), text: flags, prompt: Text(verbatim: ""))
            .font(.system(size: UIMetrics.settingsMonospacedFieldSize, design: .monospaced))
        }
        OverrideRow(
          model: model,
          project: project,
          setting: .autoStartsAgent,
          globalSetting: \.autoStartsAgent,
          label: t("agents.auto-start-tab"),
          info: t("project.auto-start-tab-info"),
          globalSection: .agentSettings,
        )
        OverrideRow(
          model: model,
          project: project,
          setting: .autoStartsAgentOnCreate,
          globalSetting: \.autoStartsAgentOnCreate,
          label: t("agents.auto-start-create"),
          info: t("project.auto-start-create-info"),
          globalSection: .agentSettings,
        )
      }
    }
  }
}
