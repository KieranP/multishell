import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Worktrees. A project overrides the path and branch prefix; the
/// rest apply to all. Sort order is not here: the sidebar's own menu holds it.
struct AppWorktreesPage: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        InfoLabeledContent(t("worktrees.path"), info: t("worktrees.path-info")) {
          TextField(t("worktrees.path"), text: model.worktreeDefaultBinding(\.worktreeDirectory))
        }
      }

      Section {
        InfoLabeledContent(t("worktrees.branch-prefix"), info: t("worktrees.branch-prefix-info")) {
          TextField(
            t("worktrees.branch-prefix"), text: model.worktreeDefaultBinding(\.branchPrefix),
            prompt: Text(t("worktrees.prefix-none")))
        }
        if let caption = model.workspace.worktreeDefaults.prefixExampleCaption {
          SettingsCaption(caption)
        }
      }

      Section {
        InfoLabeledContent(t("worktrees.hook-timeout"), info: t("worktrees.hook-timeout-info")) {
          TextField(
            t("worktrees.hook-timeout"),
            value: model.settingBinding(
              \.projectHookTimeoutSeconds, write: model.setProjectHookTimeoutSeconds),
            format: .number
          )
          .frame(width: 60)
          .multilineTextAlignment(.trailing)
          Text(t("worktrees.seconds"))
        }
      }

      Section {
        InfoLabeledContent(t("worktrees.indicator"), info: t("worktrees.indicator-info")) {
          Picker(
            t("worktrees.indicator"),
            selection: model.settingBinding(
              \.gitStatusIndicator, write: model.setGitStatusIndicator)
          ) {
            ForEach(GitStatusIndicator.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
          .fixedSize()
        }
      }

      Section {
        InfoToggle(
          t("worktrees.confirm-removal"), info: t("worktrees.confirm-removal-info"),
          isOn: model.settingBinding(
            \.confirmsWorktreeRemoval, write: model.setConfirmsWorktreeRemoval))
        InfoToggle(
          t("worktrees.delete-branch"), info: t("worktrees.delete-branch-info"),
          isOn: model.settingBinding(
            \.deletesBranchWithWorktree, write: model.setDeletesBranchWithWorktree))
        InfoToggle(
          t("worktrees.trash-removed"), info: t("worktrees.trash-removed-info"),
          isOn: model.settingBinding(
            \.trashesRemovedWorktrees, write: model.setTrashesRemovedWorktrees))
      }
    }
    .formStyle(.grouped)
  }
}
