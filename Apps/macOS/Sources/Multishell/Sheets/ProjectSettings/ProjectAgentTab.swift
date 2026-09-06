import MultishellCore
import SwiftUI

/// The project's agent override, following the global choice by default.
struct ProjectAgentTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    let global = model.workspace.preferredAgentID
    Form {
      Section {
        InfoToggle(
          "Override preferred agent",
          info:
            "New Agent Tab (⌥⌘T) in this project's worktrees starts this agent instead of the global one. None opts the project out. The custom command is the global one.",
          isOn: overrides(default: global))
        DetectionPicker(
          label: "Agent:",
          selection: Binding(
            get: { settings.preferredAgentID ?? global ?? AgentCatalogue.noneID },
            set: { model.updateSettings(with(settings, agent: $0), for: project) }),
          options: model.agentDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: "Agents found on the login shell's PATH. Refresh after installing one.",
          isEnabled: settings.preferredAgentID != nil
        )
      } footer: {
        if settings.preferredAgentID == nil {
          SettingsCaption(
            "Using the global value, \(model.agentDisplayName(global ?? AgentCatalogue.noneID)).")
        }
      }

      Section {
        InfoToggle(
          "Override auto-start",
          info:
            "Whether New Tab and a worktree's first tab here start the agent, whatever the global says.",
          isOn: overridesAutoStart)
        Toggle(
          "Start the agent in new tabs",
          isOn: Binding(
            get: { settings.autoStartAgent ?? model.workspace.autoStartAgent },
            set: { model.updateSettings(with(settings, autoStart: $0), for: project) })
        )
        .disabled(settings.autoStartAgent == nil)
      } footer: {
        if settings.autoStartAgent == nil {
          SettingsCaption(
            "Using the global value: \(model.workspace.autoStartAgent ? "on" : "off").")
        }
      }
    }
    .formStyle(.grouped)
  }

  private func with(_ settings: ProjectSettings, autoStart: Bool) -> ProjectSettings {
    var updated = settings
    updated.autoStartAgent = autoStart
    return updated
  }

  /// Turning the override on seeds it with the global value.
  private var overridesAutoStart: Binding<Bool> {
    let source = projectSetting(\.autoStartAgent, of: project, in: model)
    let global = model.workspace.autoStartAgent
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? global : nil }
    )
  }

  private func with(_ settings: ProjectSettings, agent: String) -> ProjectSettings {
    var updated = settings
    updated.preferredAgentID = agent
    return updated
  }

  /// Turning the override on seeds it with the global value, or None.
  private func overrides(default global: String?) -> Binding<Bool> {
    let source = projectSetting(\.preferredAgentID, of: project, in: model)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? (global ?? AgentCatalogue.noneID) : nil }
    )
  }
}
