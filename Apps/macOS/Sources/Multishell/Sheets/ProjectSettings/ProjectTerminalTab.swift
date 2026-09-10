import MultishellCore
import SwiftUI

/// The project's shell and open-on-create overrides, following the global
/// choices by default.
struct ProjectTerminalTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let shell = model.workspace.defaultShell ?? ShellCatalogue.loginShellID
    Form {
      OverrideSection(
        model: model, project: project, setting: \.defaultShell,
        label: "Default shell",
        info:
          "New tabs in this project's worktrees run this shell instead of the global choice, and so do its hooks. Login shell here means $SHELL whatever the global says.",
        fallback: shell
      ) { selection, isOverridden in
        DetectionPicker(
          label: "Shell:",
          selection: selection,
          options: model.shellDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            "The shells in /etc/shells and on the login shell's PATH. Refresh after installing one. Custom path is the one typed in Settings > Terminal.",
          isEnabled: isOverridden
        )
      } footer: {
        SettingsCaption(
          "Using the global value, \(model.shellDisplayName(model.workspace.defaultShell)).")
      }

      OverrideSection(
        model: model, project: project, setting: \.opensTerminalOnSelect,
        label: "Open a terminal when a worktree is selected",
        info:
          "Whether turning to a worktree here with no tabs starts its first shell, whatever the global says. A worktree just created is the setting below's to decide.",
        inherited: model.inherited(
          \.opensTerminalOnSelect, global: model.workspace.opensTerminalOnSelect, for: project))

      OverrideSection(
        model: model, project: project, setting: \.opensTerminalOnCreate,
        label: "Open a terminal when a worktree is created",
        info:
          "Whether a worktree created here opens a terminal once the create, and any post-create hook, is done, whatever the global says. Selecting a worktree is the global's to decide either way.",
        inherited: model.inherited(
          \.opensTerminalOnCreate, global: model.workspace.opensTerminalOnCreate, for: project))
    }
    .formStyle(.grouped)
  }
}
