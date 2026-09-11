import MultishellCore
import SwiftUI

/// The project's agent override, following the global choice by default.
struct ProjectAgentTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let global = model.workspace.preferredAgentID ?? AgentCatalogue.noneID
    // The flags of the agent this project actually runs, which its own
    // override may have chosen.
    let globalFlags =
      model.workspace.preferredAgentID(for: model.current(project))
      .map { model.workspace.agentFlags[$0] ?? "" } ?? ""
    Form {
      OverrideSection(
        model: model, project: project, setting: \.preferredAgentID,
        label: t("project.preferred-agent"),
        info: t("project.preferred-agent-info"),
        fallback: global
      ) { selection, isOverridden in
        DetectionPicker(
          label: t("project.agent-label"),
          selection: selection,
          options: model.agentDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: t("project.agent-picker-info"),
          isEnabled: isOverridden
        )
      } footer: {
        SettingsCaption(t("project.using-global-value", model.agentDisplayName(global)))
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
        SettingsCaption(
          globalFlags.isEmpty
            ? t("project.using-global-flags-none")
            : t("project.using-global-flags", globalFlags))
      }

      OverrideSection(
        model: model, project: project, setting: \.autoStartAgent,
        label: t("agents.auto-start-tab"),
        info: t("project.auto-start-tab-info"),
        inherited: model.inherited(
          \.autoStartAgent, global: model.workspace.autoStartAgent, for: project))

      OverrideSection(
        model: model, project: project, setting: \.autoStartAgentOnCreate,
        label: t("agents.auto-start-create"),
        info: t("project.auto-start-create-info"),
        inherited: model.inherited(
          \.autoStartAgentOnCreate, global: model.workspace.autoStartAgentOnCreate, for: project))
    }
    .formStyle(.grouped)
  }
}
