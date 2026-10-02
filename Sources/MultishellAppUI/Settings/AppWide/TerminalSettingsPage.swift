import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab runs and when one starts. The font is under Appearance with
/// the rest of the look.
struct TerminalSettingsPage: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: t("terminal.default-shell"),
          selection: Binding(get: { model.globalShellID }, set: { model.setPreferredShell($0) }),
          options: model.shellDetection.options(selected:),
          rescanning: model,
          info: t("terminal.default-shell-info")
        )
        if model.usesCustomShell {
          CustomChoiceField(
            label: t("terminal.path"), info: t("terminal.path-info"),
            prompt: t("terminal.path-prompt"),
            text: model.setting(\.customShellPath, write: model.setCustomShellPath))
          if let problem = model.customShellPathProblem {
            SettingsCaption(problem)
          }
        }
        InfoToggle(
          t("terminal.open-on-select"), info: t("terminal.open-on-select-info"),
          isOn: model.setting(\.opensTerminalOnSelect, write: model.setOpensTerminalOnSelect))
        InfoToggle(
          t("terminal.open-on-create"), info: t("terminal.open-on-create-info"),
          isOn: model.setting(\.opensTerminalOnCreate, write: model.setOpensTerminalOnCreate))
      }
    }
    .formStyle(.grouped)
  }
}
