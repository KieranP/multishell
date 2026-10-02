import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project's shell, open-on-select and open-on-create overrides,
/// following the global choices by default.
struct ProjectTerminalPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let globalShellID = model.globalShellID
    Form {
      DetectionOverrideSection(
        model: model, project: project, setting: \.preferredShellID,
        label: t("project.default-shell"),
        info: t("project.default-shell-info"),
        pickerLabel: t("project.shell-label"),
        pickerInfo: t("project.shell-picker-info"),
        options: model.shellDetection.options(selected:),
        globalID: globalShellID,
        globalName: model.shellDisplayName(globalShellID))

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
