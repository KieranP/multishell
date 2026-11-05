import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab runs and when one starts. The font is under Appearance with
/// the rest of the look.
struct AppTerminalPage: View {
  let model: AppModel

  var body: some View {
    SettingsForm {
      SettingsGroup(t("terminal.section-new-tabs")) {
        DetectionPicker(
          label: t("terminal.default-shell"),
          selection: model.preferredShellBinding,
          options: model.shellDetection.options(selected:),
          refreshing: model,
          info: t("terminal.default-shell-info"),
        )
        if model.usesCustomShell {
          CustomChoiceField(
            label: t("terminal.path"),
            info: t("terminal.path-info"),
            prompt: t("terminal.path-prompt"),
            text: model.settingBinding(\.customShellPath, write: model.setCustomShellPath),
          )
          if let problem = model.customShellPathProblem {
            SettingsCaption(problem)
          }
        }
      }

      SettingsGroup(t("terminal.section-first-terminal")) {
        InfoToggle(
          t("terminal.open-on-select"),
          info: t("terminal.open-on-select-info"),
          isOn: model.settingBinding(
            \.opensTerminalOnSelect,
            write: model.setOpensTerminalOnSelect,
          ),
        )
        InfoToggle(
          t("terminal.open-on-create"),
          info: t("terminal.open-on-create-info"),
          isOn: model.settingBinding(
            \.opensTerminalOnCreate,
            write: model.setOpensTerminalOnCreate,
          ),
        )
      }
    }
  }
}
