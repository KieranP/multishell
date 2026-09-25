import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

struct ProjectWorktreesPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let effective = model.worktreeSettings(for: project)
    let exampleBranch = effective.exampleBranch

    Form {
      OverrideSection(
        model: model, project: project, setting: .worktreeDirectory,
        global: defaults.worktreeDirectory,
        label: t("project.worktree-path"),
        info: t("project.worktree-path-info")
      ) { binding, isOverridden, inherited in
        TextField(t("project.path-label"), text: binding).disabled(!isOverridden)
        let container = effective.worktreeContainer(for: project).path
        SettingsCaption(inherited.containerCaption(container, isOverridden: isOverridden))
      }

      OverrideSection(
        model: model, project: project, setting: .branchPrefix,
        global: defaults.branchPrefix,
        label: t("project.branch-prefix"),
        info: t("project.branch-prefix-info")
      ) { binding, isOverridden, inherited in
        TextField(
          t("project.prefix-label"), text: binding, prompt: Text(t("worktrees.prefix-none"))
        )
        .disabled(!isOverridden)
        let examplePath = effective.worktreePath(forBranch: exampleBranch, in: project).path
        SettingsCaption(
          inherited.prefixExampleCaption(
            branch: exampleBranch, path: examplePath, isOverridden: isOverridden))
      }

      OverrideSection(
        model: model, project: project, setting: \.defaultBranch,
        label: t("project.default-branch"),
        info: t("project.default-branch-info"),
        fallback: model.defaultBranchName(of: project)
      ) { binding, isOverridden in
        TextField(
          t("project.branch-label"), text: binding,
          prompt: Text(verbatim: AppModel.usualDefaultBranchName)
        )
        .disabled(!isOverridden)
        SettingsCaption(
          model.defaultBranch(of: project).map { t("project.merges-measured", $0.shortName) }
            ?? t("project.no-merge-base"))
      }
    }
    .formStyle(.grouped)
  }
}
