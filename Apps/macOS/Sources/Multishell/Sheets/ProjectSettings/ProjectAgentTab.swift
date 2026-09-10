import MultishellCore
import SwiftUI

/// The project's agent override, following the global choice by default.
struct ProjectAgentTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let global = model.workspace.preferredAgentID ?? AgentCatalogue.noneID
    Form {
      OverrideSection(
        model: model, project: project, setting: \.preferredAgentID,
        label: "Preferred agent",
        info:
          "New Agent Tab (⌥⌘T) in this project's worktrees starts this agent instead of the global one. None opts the project out. The custom command is the global one.",
        fallback: global
      ) { selection, isOverridden in
        DetectionPicker(
          label: "Agent:",
          selection: selection,
          options: model.agentDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: "Agents found on the login shell's PATH. Refresh after installing one.",
          isEnabled: isOverridden
        )
      } footer: {
        SettingsCaption("Using the global value, \(model.agentDisplayName(global)).")
      }

      OverrideSection(
        model: model, project: project, setting: \.autoStartAgent,
        label: "Auto-start on tab open",
        info:
          "Whether New Tab, and the first tab of a worktree turned to here, start the agent, whatever the global says.",
        inherited: model.inherited(
          \.autoStartAgent, global: model.workspace.autoStartAgent, for: project))

      OverrideSection(
        model: model, project: project, setting: \.autoStartAgentOnCreate,
        label: "Auto-start on worktree creation",
        info:
          "Whether the tab a worktree created here opens starts the agent, whatever the global says. Nothing opens at all unless the Terminal tab opens one on create.",
        inherited: model.inherited(
          \.autoStartAgentOnCreate, global: model.workspace.autoStartAgentOnCreate, for: project))
    }
    .formStyle(.grouped)
  }
}
