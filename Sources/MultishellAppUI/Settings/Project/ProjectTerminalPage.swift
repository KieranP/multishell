import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project's shell and when its first terminal opens, beside the global
/// choices it follows until overridden.
struct ProjectTerminalPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    SettingsForm {
      OverrideTable {
        OverrideRow(
          model: model,
          project: project,
          setting: \.preferredShellID,
          label: t("project.default-shell"),
          info: t("project.default-shell-info"),
          options: model.shellDetection.options(selected:),
          globalValue: model.globalShellValue,
          globalID: model.globalShellID,
        )
        OverrideRow(
          model: model,
          project: project,
          setting: .opensTerminalOnSelect,
          globalSetting: \.opensTerminalOnSelect,
          label: t("project.open-on-select-short"),
          info: t("project.open-on-select-info"),
          globalSection: .terminal,
        )
        OverrideRow(
          model: model,
          project: project,
          setting: .opensTerminalOnCreate,
          globalSetting: \.opensTerminalOnCreate,
          label: t("project.open-on-create-short"),
          info: t("project.open-on-create-info"),
          globalSection: .terminal,
        )
      }
    }
  }
}
