import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > General: the editor Open in Editor uses, notifications, and
/// where the state file is.
struct GeneralSettingsTab: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        DetectionPicker(
          label: "Editor:",
          selection: Binding(
            get: { model.workspace.preferredEditorID ?? EditorCatalogue.noneID },
            set: { model.setPreferredEditor($0) }),
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
              text: Binding(
                get: { model.workspace.customEditorCommand },
                set: { model.setCustomEditorCommand($0) }),
              prompt: Text("code-insiders {path}"))
          }
        }
      }

      Section {
        InfoRow(
          "Notifications:",
          info:
            "A system notification when a tab you are not looking at needs input, or finishes: an agent's turn, or a shell command that ran longer than ten seconds. Off by default; macOS asks for permission the first time one is posted."
        ) {
          Picker("Notifications:", selection: notifications) {
            ForEach(NotificationPreference.allCases, id: \.self) { Text($0.displayName).tag($0) }
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

  private var notifications: Binding<NotificationPreference> {
    Binding(get: { model.workspace.notifications }, set: { model.setNotifications($0) })
  }
}
