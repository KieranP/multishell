import MultishellCore
import SwiftUI

/// The project's shell and open-on-create overrides, following the global
/// choices by default.
struct ProjectTerminalTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.settings(of: project)
    let onSelect = model.inherited(
      \.opensTerminalOnSelect, global: model.workspace.opensTerminalOnSelect, for: project)
    let onCreate = model.inherited(
      \.opensTerminalOnCreate, global: model.workspace.opensTerminalOnCreate, for: project)
    Form {
      Section {
        InfoToggle(
          "Override: Default shell",
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

      Section {
        InfoToggle(
          "Override: Open a terminal when a worktree is selected",
          info:
            "Whether turning to a worktree here with no tabs starts its first shell, whatever the global says. A worktree just created is the setting below's to decide.",
          isOn: overrides(\.opensTerminalOnSelect, default: onSelect.value))
        Toggle(
          "Open a terminal when a worktree is selected",
          isOn: value(\.opensTerminalOnSelect, default: onSelect.value)
        )
        .disabled(settings.opensTerminalOnSelect == nil)
      } footer: {
        if settings.opensTerminalOnSelect == nil { SettingsCaption(onSelect.caption) }
      }

      Section {
        InfoToggle(
          "Override: Open a terminal when a worktree is created",
          info:
            "Whether a worktree created here opens a terminal once the create, and any post-create hook, is done, whatever the global says. Selecting a worktree is the global's to decide either way.",
          isOn: overrides(\.opensTerminalOnCreate, default: onCreate.value))
        Toggle(
          "Open a terminal when a worktree is created",
          isOn: value(\.opensTerminalOnCreate, default: onCreate.value)
        )
        .disabled(settings.opensTerminalOnCreate == nil)
      } footer: {
        if settings.opensTerminalOnCreate == nil { SettingsCaption(onCreate.caption) }
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

  /// Turning the override on seeds it with the global value, or the login
  /// shell; turning it off returns to following the global.
  private var overridesShell: Binding<Bool> {
    let source = model.setting(\.defaultShell, of: project)
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
