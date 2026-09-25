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
        label: t("project.default-shell"),
        info: t("project.default-shell-info"),
        fallback: shell
      ) { selection, isOverridden in
        DetectionPicker(
          label: t("project.shell-label"),
          selection: selection,
          options: model.shellDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            t("project.shell-picker-info"),
          isEnabled: isOverridden
        )
      } footer: {
        SettingsCaption(
          t(
            "project.using-global-value",
            model.shellDisplayName(model.workspace.defaultShell)))
      }

      OverrideSection(
        model: model, project: project, setting: \.opensTerminalOnSelect,
        label: t("terminal.open-on-select"),
        info: t("project.open-on-select-info"),
        inherited: model.inherited(
          \.opensTerminalOnSelect, global: model.workspace.opensTerminalOnSelect, for: project))

      OverrideSection(
        model: model, project: project, setting: \.opensTerminalOnCreate,
        label: t("terminal.open-on-create"),
        info: t("project.open-on-create-info"),
        inherited: model.inherited(
          \.opensTerminalOnCreate, global: model.workspace.opensTerminalOnCreate, for: project))
    }
    .formStyle(.grouped)
  }
}
