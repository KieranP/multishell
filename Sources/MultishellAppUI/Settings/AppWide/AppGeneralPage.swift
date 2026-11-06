import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > General: the editor Open in Editor uses, and where the state
/// file is.
struct AppGeneralPage: View {
  let model: AppModel

  var body: some View {
    SettingsForm {
      SettingsGroup(t("general.section-editor")) {
        DetectionPicker(
          label: t("general.editor"),
          selection: model.settingBinding(
            \.preferredEditorID,
            or: EditorCatalogue.noneID,
            write: model.setPreferredEditor,
          ),
          options: model.editorDetection.options(selected:),
          refreshing: model,
          info: t("general.editor-info"),
        )
        if model.usesCustomEditor {
          CustomChoiceField(
            label: t("label.command"),
            info: t("general.editor-command-info"),
            prompt: t("general.editor-command-prompt"),
            text: model.settingBinding(\.customEditorCommand, write: model.setCustomEditorCommand),
          )
        }
      }

      SettingsGroup(t("general.section-storage")) {
        InfoLabeledContent(t("general.state-file"), info: t("general.state-file-info")) {
          PathText(Paths.stateFile.path)
          SettingsSymbolButton.reveal { model.revealInFileBrowser(Paths.stateFile) }
        }
      }
    }
  }
}
