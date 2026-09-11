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
        model: model, project: project, setting: \.agentFlags,
        label: "CLI Flags",
        info:
          "Added to this project's agent command line instead of the global flags. Blank runs it with none, whatever the global passes.",
        fallback: globalFlags
      ) { flags, isOverridden in
        TextField("CLI Flags:", text: flags)
          .disabled(!isOverridden)
      } footer: {
        SettingsCaption(
          globalFlags.isEmpty
            ? "Using the global flags, which are none." : "Using the global flags, \(globalFlags).")
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
