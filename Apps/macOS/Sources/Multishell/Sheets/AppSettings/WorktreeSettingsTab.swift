import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Worktrees: where new worktrees go, how their branches are
/// named, and what a removal asks. Any project can override these.
struct WorktreeSettingsTab: View {
  let model: AppModel

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    Form {
      Section {
        InfoRow(t("worktrees.path"), info: t("worktrees.path-info")) {
          TextField(t("worktrees.path"), text: field(\.worktreeDirectory))
        }
      }

      Section {
        InfoRow(t("worktrees.branch-prefix"), info: t("worktrees.branch-prefix-info")) {
          TextField(
            t("worktrees.branch-prefix"), text: field(\.branchPrefix),
            prompt: Text(t("worktrees.prefix-none")))
        }
        if !defaults.branchPrefix.isEmpty {
          SettingsCaption(t("worktrees.prefix-example", defaults.qualifiedBranch("tabs")))
        }
      }

      Section {
        InfoRow(t("worktrees.sort"), info: t("worktrees.sort-info")) {
          Picker(
            t("worktrees.sort"),
            selection: model.setting(\.worktreeSortOrder, write: model.setWorktreeSortOrder)
          ) {
            ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
        }
        InfoToggle(
          t("worktrees.active-first"), info: t("worktrees.active-first-info"),
          isOn: model.setting(
            \.showsActiveWorktreesFirst, write: model.setShowsActiveWorktreesFirst))
      }

      Section {
        InfoRow(t("worktrees.hook-timeout"), info: t("worktrees.hook-timeout-info")) {
          TextField(
            t("worktrees.hook-timeout"),
            value: model.setting(\.hookTimeoutSeconds, write: model.setHookTimeoutSeconds),
            format: .number
          )
          .frame(width: 60)
          .multilineTextAlignment(.trailing)
          Text(t("worktrees.seconds"))
        }
      }

      Section {
        InfoToggle(
          t("worktrees.confirm-removal"), info: t("worktrees.confirm-removal-info"),
          isOn: model.setting(
            \.confirmsWorktreeRemoval, write: model.setConfirmsWorktreeRemoval))
        InfoToggle(
          t("worktrees.delete-branch"), info: t("worktrees.delete-branch-info"),
          isOn: model.setting(
            \.deletesBranchWithWorktree, write: model.setDeletesBranchWithWorktree))
      }
    }
    .formStyle(.grouped)
  }

  private func field(_ keyPath: WritableKeyPath<WorktreeSettings, String>) -> Binding<String> {
    Binding(
      get: { model.workspace.worktreeDefaults[keyPath: keyPath] },
      set: { value in
        var defaults = model.workspace.worktreeDefaults
        defaults[keyPath: keyPath] = value
        model.setWorktreeDefaults(defaults)
      }
    )
  }
}
