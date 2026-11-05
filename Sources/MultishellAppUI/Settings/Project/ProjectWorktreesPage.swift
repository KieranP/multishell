import MultishellAppCore
import MultishellCore
import SwiftUI

/// Where the project's worktrees go, how their branches are named, and the
/// branch they merge into, beside the values it follows until overridden.
struct ProjectWorktreesPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    SettingsForm {
      OverrideTable(t("project.table-new-worktrees")) {
        OverrideRow(
          model: model,
          project: project,
          setting: .worktreeDirectory,
          global: defaults.worktreeDirectory,
          label: t("project.worktree-path"),
          info: t("project.worktree-path-info"),
          column: \.directoryGlobalValue,
          caption: { model.worktreeContainerCaption(for: project, isOverridden: $0) },
          control: { path in TextField(t("project.worktree-path"), text: path) },
        )
        OverrideRow(
          model: model,
          project: project,
          setting: .branchPrefix,
          global: defaults.branchPrefix,
          label: t("project.branch-prefix"),
          info: t("project.branch-prefix-info"),
          column: \.prefixGlobalValue,
          caption: { model.branchPrefixCaption(for: project, isOverridden: $0) },
          control: { prefix in
            TextField(
              t("project.branch-prefix"),
              text: prefix,
              prompt: Text(t("worktrees.prefix-none")),
            )
          },
        )
        OverrideRow(
          model: model,
          project: project,
          setting: \.defaultBranch,
          label: t("project.default-branch"),
          info: t("project.default-branch-info"),
          column: model.defaultBranchGlobalValue(for: project),
          fallback: model.defaultBranchName(of: project),
          caption: { _ in model.defaultBranchCaption(for: project) },
          control: { branch in
            TextField(
              t("project.default-branch"),
              text: branch,
              prompt: Text(verbatim: AppModel.usualDefaultBranchName),
            )
          },
        )
      }
    }
  }
}
