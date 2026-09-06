import MultishellCore
import SwiftUI

/// The project's shell override, following the global choice by default.
struct ProjectTerminalTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.workspace.project(project.id)?.settings ?? project.settings
    Form {
      Section {
        InfoToggle(
          "Override default shell",
          info:
            "New tabs in this project's worktrees run this shell instead of the global choice, and so do its hooks. Login shell here means $SHELL whatever the global says.",
          isOn: overridesShell)
        DetectionPicker(
          label: "Shell:",
          selection: Binding(
            get: {
              settings.defaultShell ?? model.workspace.defaultShell ?? ShellCatalogue.loginShellID
            },
            set: { model.updateSettings(with(settings, shell: $0), for: project) }),
          options: model.shellDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            "The shells in /etc/shells and on the login shell's PATH. Refresh after installing one. Custom path is the one typed in Settings > Terminal.",
          isEnabled: settings.defaultShell != nil
        )
      } footer: {
        if settings.defaultShell == nil {
          SettingsCaption(
            "Using the global value, \(model.shellDisplayName(model.workspace.defaultShell)).")
        }
      }
    }
    .formStyle(.grouped)
  }

  /// Turning the override on seeds it with the global value, or the login
  /// shell; turning it off returns to following the global.
  private var overridesShell: Binding<Bool> {
    let source = projectSetting(\.defaultShell, of: project, in: model)
    let global = model.workspace.defaultShell ?? ShellCatalogue.loginShellID
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? global : nil }
    )
  }

  private func with(_ settings: ProjectSettings, shell: String) -> ProjectSettings {
    var updated = settings
    updated.defaultShell = shell
    return updated
  }
}
