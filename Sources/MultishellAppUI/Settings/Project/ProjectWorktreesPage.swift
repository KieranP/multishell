import MultishellAppCore
import MultishellCore
import SwiftUI

/// Where the project's worktrees go, how their branches are named, the branch
/// they merge into, and where conflicts from it go, beside the values it follows.
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
          globalValue: \.directoryGlobalValue,
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
          globalValue: \.prefixGlobalValue,
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
          globalValue: model.defaultBranchGlobalValue(for: project),
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
      OverrideTable(t("project.table-updating")) {
        OverrideRow(
          model: model,
          project: project,
          setting: \.sendsConflictsToPreferredAgent,
          label: t("worktrees.send-conflicts"),
          info: t("project.send-conflicts-info"),
          globalValue: model.sendsConflictsGlobalValue,
          fallback: model.workspace.sendsConflictsToPreferredAgentGlobally,
          caption: { _ in model.agentNeededCaption(in: project) },
          control: { isOn in
            SettingsSwitch(label: t("worktrees.send-conflicts"), isOn: isOn)
              .disabled(!model.hasAgent(in: project))
          },
        )
      }
    }
  }
}
