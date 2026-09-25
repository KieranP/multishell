import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > General: the editor Open in Editor uses, and where the state
/// file is.
struct GeneralSettingsPage: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: t("general.editor"),
          selection: model.setting(
            \.preferredEditorID, or: EditorCatalogue.noneID, write: model.setPreferredEditor),
          options: model.editorDetection.options(selected:),
          rescanning: model,
          info: t("general.editor-info")
        )
        if model.usesCustomEditor {
          CustomCommandRow(
            label: t("label.command"), info: t("general.editor-command-info"),
            prompt: t("general.editor-command-prompt"),
            text: model.setting(\.customEditorCommand, write: model.setCustomEditorCommand))
        }
      }

      Section {
        InfoLabeledContent(t("general.state-file"), info: t("general.state-file-info")) {
          PathText(Paths.stateFile.path)
          SymbolButton.reveal { model.revealInFileBrowser(Paths.stateFile) }
            .controlSize(.small)
        }
      }
    }
    .formStyle(.grouped)
  }
}
