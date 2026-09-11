import MultishellAppCore
import MultishellCore
import SwiftUI

/// What a tab runs and when one starts. The font is under Appearance with
/// the rest of the look.
struct TerminalSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        InfoRow(t("terminal.engine"), info: engineInfo) {
          Picker(
            t("terminal.engine"),
            selection: model.setting(\.terminalEngine, write: model.setTerminalEngine)
          ) {
            ForEach(TerminalEngine.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
        }
        DetectionPicker(
          label: t("terminal.default-shell"),
          selection: model.setting(
            \.defaultShell, or: ShellCatalogue.loginShellID, write: model.setDefaultShell),
          options: model.shellDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: t("terminal.default-shell-info")
        )
        if model.workspace.defaultShell == ShellCatalogue.customID {
          InfoRow(t("terminal.path"), info: t("terminal.path-info")) {
            TextField(
              t("terminal.path"),
              text: model.setting(\.customShellPath, write: model.setCustomShellPath),
              prompt: Text(t("terminal.path-prompt")))
          }
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

  private var engineInfo: String {
    model.workspace.terminalEngine == .swiftTerm
      ? t("terminal.engine-info-swift-term") : t("terminal.engine-info")
  }
}
