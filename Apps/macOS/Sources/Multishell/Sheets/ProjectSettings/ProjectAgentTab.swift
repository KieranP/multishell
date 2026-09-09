import MultishellCore
import SwiftUI

/// The project's agent override, following the global choice by default.
struct ProjectAgentTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.settings(of: project)
    let global = model.workspace.preferredAgentID ?? AgentCatalogue.noneID
    let onTabOpen = model.inherited(
      \.autoStartAgent, global: model.workspace.autoStartAgent, for: project)
    let onCreate = model.inherited(
      \.autoStartAgentOnCreate, global: model.workspace.autoStartAgentOnCreate, for: project)
    Form {
      Section {
        InfoToggle(
          "Override: Preferred agent",
          info:
            "New Agent Tab (⌥⌘T) in this project's worktrees starts this agent instead of the global one. None opts the project out. The custom command is the global one.",
          isOn: model.hasOverride(\.preferredAgentID, of: project, fallback: global))
        DetectionPicker(
          label: "Agent:",
          selection: model.overrideValue(\.preferredAgentID, of: project, fallback: global),
          options: model.agentDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: "Agents found on the login shell's PATH. Refresh after installing one.",
          isEnabled: settings.preferredAgentID != nil
        )
      } footer: {
        if settings.preferredAgentID == nil {
          SettingsCaption("Using the global value, \(model.agentDisplayName(global)).")
        }
      }

      Section {
        InfoToggle(
          "Override: Auto-start on tab open",
          info:
            "Whether New Tab, and the first tab of a worktree turned to here, start the agent, whatever the global says.",
          isOn: model.hasOverride(\.autoStartAgent, of: project, fallback: onTabOpen.value))
        Toggle(
          "Auto-start on tab open",
          isOn: model.overrideValue(\.autoStartAgent, of: project, fallback: onTabOpen.value)
        )
        .disabled(settings.autoStartAgent == nil)
      } footer: {
        if settings.autoStartAgent == nil { SettingsCaption(onTabOpen.caption) }
      }

      Section {
        InfoToggle(
          "Override: Auto-start on worktree creation",
          info:
            "Whether the tab a worktree created here opens starts the agent, whatever the global says. Nothing opens at all unless the Terminal tab opens one on create.",
          isOn: model.hasOverride(\.autoStartAgentOnCreate, of: project, fallback: onCreate.value))
        Toggle(
          "Auto-start on worktree creation",
          isOn: model.overrideValue(
            \.autoStartAgentOnCreate, of: project, fallback: onCreate.value)
        )
        .disabled(settings.autoStartAgentOnCreate == nil)
      } footer: {
        if settings.autoStartAgentOnCreate == nil { SettingsCaption(onCreate.caption) }
      }
    }
    .formStyle(.grouped)
  }
}
