import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project's agent override, following the global choice by default.
struct ProjectAgentsPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let globalAgentID = model.workspace.preferredAgentID ?? AgentCatalogue.noneID
    let globalFlags = model.workspace.globalAgentFlags(for: project)
    Form {
      OverrideSection(
        model: model, project: project, setting: \.preferredAgentID,
        label: t("project.preferred-agent"),
        info: t("project.preferred-agent-info"),
        fallback: globalAgentID
      ) { selection, isOverridden in
        DetectionPicker(
          label: t("project.agent-label"),
          selection: selection,
          options: model.agentDetection.options(selected:),
          rescanning: model,
          info: t("project.agent-picker-info"),
          isEnabled: isOverridden
        )
      } footer: {
        SettingsCaption(t("project.using-global-value", model.agentDisplayName(globalAgentID)))
      }

      OverrideSection(
        model: model, project: project, setting: \.agentFlags,
        label: t("project.flags"),
        info: t("project.flags-info"),
        fallback: globalFlags
      ) { flags, isOverridden in
        TextField(t("agents.flags"), text: flags)
          .disabled(!isOverridden)
      } footer: {
        SettingsCaption(model.globalAgentFlagsCaption(for: project))
      }

      OverrideSection(
        model: model, project: project, setting: .autoStartAgent, global: \.autoStartAgent,
        label: t("agents.auto-start-tab"),
        info: t("project.auto-start-tab-info"))

      OverrideSection(
        model: model, project: project, setting: .autoStartAgentOnCreate,
        global: \.autoStartAgentOnCreate,
        label: t("agents.auto-start-create"),
        info: t("project.auto-start-create-info"))
    }
    .formStyle(.grouped)
  }
}
