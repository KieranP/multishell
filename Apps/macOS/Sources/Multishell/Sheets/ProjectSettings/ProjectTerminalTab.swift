import MultishellCore
import SwiftUI

/// The project's shell and open-on-create overrides, following the global
/// choices by default.
struct ProjectTerminalTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let settings = model.settings(of: project)
    let shell = model.workspace.defaultShell ?? ShellCatalogue.loginShellID
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
          isOn: model.hasOverride(\.defaultShell, of: project, fallback: shell))
        DetectionPicker(
          label: "Shell:",
          selection: model.overrideValue(\.defaultShell, of: project, fallback: shell),
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
          isOn: model.hasOverride(\.opensTerminalOnSelect, of: project, fallback: onSelect.value))
        Toggle(
          "Open a terminal when a worktree is selected",
          isOn: model.overrideValue(\.opensTerminalOnSelect, of: project, fallback: onSelect.value)
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
          isOn: model.hasOverride(\.opensTerminalOnCreate, of: project, fallback: onCreate.value))
        Toggle(
          "Open a terminal when a worktree is created",
          isOn: model.overrideValue(\.opensTerminalOnCreate, of: project, fallback: onCreate.value)
        )
        .disabled(settings.opensTerminalOnCreate == nil)
      } footer: {
        if settings.opensTerminalOnCreate == nil { SettingsCaption(onCreate.caption) }
      }
    }
    .formStyle(.grouped)
  }
}
