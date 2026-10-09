import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectWorktreesPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults

    Form {
      OverrideSection(
        model: model,
        project: project,
        setting: .worktreeDirectory,
        global: defaults.worktreeDirectory,
        label: t("project.worktree-path"),
        info: t("project.worktree-path-info"),
      ) { binding, isOverridden, _ in
        TextField(t("project.path-label"), text: binding).disabled(!isOverridden)
        SettingsCaption(model.worktreeContainerCaption(for: project, isOverridden: isOverridden))
      }

      OverrideSection(
        model: model,
        project: project,
        setting: .branchPrefix,
        global: defaults.branchPrefix,
        label: t("project.branch-prefix"),
        info: t("project.branch-prefix-info"),
      ) { binding, isOverridden, _ in
        TextField(
          t("project.prefix-label"),
          text: binding,
          prompt: Text(t("worktrees.prefix-none")),
        )
        .disabled(!isOverridden)
        SettingsCaption(model.branchPrefixCaption(for: project, isOverridden: isOverridden))
      }

      OverrideSection(
        model: model,
        project: project,
        setting: \.defaultBranch,
        label: t("project.default-branch"),
        info: t("project.default-branch-info"),
        fallback: model.defaultBranchName(of: project),
      ) { binding, isOverridden in
        TextField(
          t("project.branch-label"),
          text: binding,
          prompt: Text(verbatim: AppModel.usualDefaultBranchName),
        )
        .disabled(!isOverridden)
        SettingsCaption(model.defaultBranchCaption(for: project))
      }
    }
    .formStyle(.grouped)
  }
}
