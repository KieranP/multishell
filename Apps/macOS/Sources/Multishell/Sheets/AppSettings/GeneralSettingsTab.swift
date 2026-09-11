import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > General: the editor Open in Editor uses, and where the state
/// file is.
struct GeneralSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: t("general.editor"),
          selection: model.setting(
            \.preferredEditorID, or: EditorCatalogue.noneID, write: model.setPreferredEditor),
          options: model.editorDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info: t("general.editor-info")
        )
        if model.workspace.preferredEditorID == EditorCatalogue.customID {
          InfoRow(t("agents.command"), info: t("general.editor-command-info")) {
            TextField(
              t("agents.command"),
              text: model.setting(\.customEditorCommand, write: model.setCustomEditorCommand),
              prompt: Text(t("general.editor-command-prompt")))
          }
        }
      }

      Section {
        InfoRow(t("general.state-file"), info: t("general.state-file-info")) {
          Text(Paths.stateFile.path)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
          IconButton.reveal { model.revealInFileBrowser(Paths.stateFile) }
            .controlSize(.small)
        }
      }
    }
    .formStyle(.grouped)
  }
}
