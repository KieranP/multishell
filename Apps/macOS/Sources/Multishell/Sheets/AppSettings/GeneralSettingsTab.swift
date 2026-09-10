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
          label: "Editor:",
          selection: model.setting(
            \.preferredEditorID, or: EditorCatalogue.noneID, write: model.setPreferredEditor),
          options: model.editorDetection.options(selected:),
          refresh: { Task { await model.refreshLoginEnvironment() } },
          info:
            "What Open in Editor (⇧⌘O) in the worktree menu uses. Applications are found by bundle identifier, or by their command line shim on the login shell's PATH; a terminal editor opens as a new tab in the worktree."
        )
        if model.workspace.preferredEditorID == EditorCatalogue.customID {
          InfoRow(
            "Command:",
            info:
              "Run as a new tab in the worktree through your login shell, with {path} replaced by the worktree's quoted path, or the path appended if {path} is absent. A shell takes over when it exits."
          ) {
            TextField(
              "Command:",
              text: model.setting(\.customEditorCommand, write: model.setCustomEditorCommand),
              prompt: Text("code-insiders {path}"))
          }
        }
      }

      Section {
        InfoRow(
          "State file:",
          info:
            "Projects, worktrees, tabs and these settings. Running shells are not saved; each tab gets a fresh one on relaunch."
        ) {
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
