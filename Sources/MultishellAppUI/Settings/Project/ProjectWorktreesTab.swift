import MultishellAppCore
import MultishellCore
import MultishellGitKit
import SwiftUI

struct ProjectWorktreesTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let defaults = model.workspace.worktreeDefaults
    let effective = model.worktreeSettings(for: project)
    let branch = effective.exampleBranch

    Form {
      OverrideSection(
        model: model, project: project, setting: .worktreeDirectory,
        global: defaults.worktreeDirectory,
        label: t("project.worktree-path"),
        info: t("project.worktree-path-info")
      ) { path, isOverridden, directory in
        TextField(t("project.path-label"), text: path).disabled(!isOverridden)
        let container = effective.worktreeContainer(for: project).path
        SettingsCaption(
          !isOverridden && directory.isFromRepository
            ? t("project.resolves-to-shared", container, SharedProjectSettings.fileName)
            : t("project.resolves-to", container))
      }

      OverrideSection(
        model: model, project: project, setting: .branchPrefix,
        global: defaults.branchPrefix,
        label: t("project.branch-prefix"),
        info: t("project.branch-prefix-info")
      ) { text, isOverridden, prefix in
        TextField(
          t("project.prefix-label"), text: text, prompt: Text(t("worktrees.prefix-none"))
        )
        .disabled(!isOverridden)
        let path = effective.worktreePath(forBranch: branch, in: project).path
        SettingsCaption(
          !isOverridden && prefix.isFromRepository
            ? t(
              "project.prefix-example-shared",
              branch, path, SharedProjectSettings.fileName)
            : t("project.prefix-example", branch, path))
      }

      OverrideSection(
        model: model, project: project, setting: \.defaultBranch,
        label: t("project.default-branch"),
        info: t("project.default-branch-info"),
        fallback: detected
      ) { text, isOverridden in
        TextField(t("project.branch-label"), text: text, prompt: Text(verbatim: "main"))
          .disabled(!isOverridden)
        SettingsCaption(
          model.mergeBase(of: project).map { t("project.merges-measured", $0.shortName) }
            ?? t("project.no-merge-base"))
      }
    }
    .formStyle(.grouped)
  }

  /// What the field shows while the override is off: the resolved branch,
  /// without its remote, so the override seeds `main` not `origin/main`.
  private var detected: String {
    model.mergeBase(of: project)?.branchName ?? "main"
  }
}
