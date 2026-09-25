import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project's shell, open-on-select and open-on-create overrides,
/// following the global choices by default.
struct ProjectTerminalPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let globalShellID = model.workspace.preferredShellID ?? ShellCatalogue.loginShellID
    Form {
      OverrideSection(
        model: model, project: project, setting: \.preferredShellID,
        label: t("project.default-shell"),
        info: t("project.default-shell-info"),
        fallback: globalShellID
      ) { selection, isOverridden in
        DetectionPicker(
          label: t("project.shell-label"),
          selection: selection,
          options: model.shellDetection.options(selected:),
          rescanning: model,
          info: t("project.shell-picker-info"),
          isEnabled: isOverridden
        )
      } footer: {
        SettingsCaption(t("project.using-global-value", model.shellDisplayName(globalShellID)))
      }

      OverrideSection(
        model: model, project: project, setting: .opensTerminalOnSelect,
        global: \.opensTerminalOnSelect,
        label: t("terminal.open-on-select"),
        info: t("project.open-on-select-info"))

      OverrideSection(
        model: model, project: project, setting: .opensTerminalOnCreate,
        global: \.opensTerminalOnCreate,
        label: t("terminal.open-on-create"),
        info: t("project.open-on-create-info"))
    }
    .formStyle(.grouped)
  }
}
