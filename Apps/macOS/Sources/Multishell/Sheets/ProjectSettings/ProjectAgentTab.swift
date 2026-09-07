import MultishellCore
import SwiftUI

/// The project's agent override, following the global choice by default.
struct ProjectAgentTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.settings(of: project)
    let global = model.workspace.preferredAgentID
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
          "Override: Auto-start on tab open",
          info:
            "Whether New Tab, and the first tab of a worktree turned to here, start the agent, whatever the global says.",
          isOn: overrides(\.autoStartAgent, default: onTabOpen.value))
        Toggle("Auto-start on tab open", isOn: value(\.autoStartAgent, default: onTabOpen.value))
          .disabled(settings.autoStartAgent == nil)
      } footer: {
        if settings.autoStartAgent == nil { SettingsCaption(onTabOpen.caption) }
      }

      Section {
        InfoToggle(
          "Override: Auto-start on worktree creation",
          info:
            "Whether the tab a worktree created here opens starts the agent, whatever the global says. Nothing opens at all unless the Terminal tab opens one on create.",
          isOn: overrides(\.autoStartAgentOnCreate, default: onCreate.value))
        Toggle(
          "Auto-start on worktree creation",
          isOn: value(\.autoStartAgentOnCreate, default: onCreate.value)
        )
        .disabled(settings.autoStartAgentOnCreate == nil)
      } footer: {
        if settings.autoStartAgentOnCreate == nil { SettingsCaption(onCreate.caption) }
      }
    }
    .formStyle(.grouped)
  }

  /// Turning an override on seeds it with the global value; turning it off
  /// returns to following the global.
  private func overrides(
    _ keyPath: WritableKeyPath<ProjectSettings, Bool?>, default global: Bool
  ) -> Binding<Bool> {
    let source = model.setting(keyPath, of: project)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? global : nil }
    )
  }

  /// The overridden value, showing the global while it is not overridden.
  private func value(
    _ keyPath: WritableKeyPath<ProjectSettings, Bool?>, default global: Bool
  ) -> Binding<Bool> {
    let source = model.setting(keyPath, of: project)
    return Binding(get: { source.wrappedValue ?? global }, set: { source.wrappedValue = $0 })
  }

  private func with(_ settings: ProjectSettings, agent: String) -> ProjectSettings {
    var updated = settings
    updated.preferredAgentID = agent
    return updated
  }

  /// Turning the override on seeds it with the global value, or None.
  private func overrides(default global: String?) -> Binding<Bool> {
    let source = model.setting(\.preferredAgentID, of: project)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? (global ?? AgentCatalogue.noneID) : nil }
    )
  }
}
