import MultishellAppCore
import MultishellCore
import SwiftUI

/// Settings > Worktrees, in two parts as it outgrew the window. A project overrides
/// the path, the branch prefix and sending conflicts. The sidebar's own menu holds sort order.
struct AppWorktreesPage: View {
  let model: AppModel
  /// Which part: creating and ports, or what happens to a worktree once made.
  let section: SettingsSection

  var body: some View {
    SettingsForm {
      if section == .worktreesNew {
        newWorktreeGroups
      } else {
        existingWorktreeGroups
      }
    }
  }

  @ViewBuilder private var newWorktreeGroups: some View {
    SettingsGroup(t("worktrees.section-creating")) {
      InfoLabeledContent(t("worktrees.path"), info: t("worktrees.path-info")) {
        TextField(t("worktrees.path"), text: model.worktreeDefaultBinding(\.worktreeDirectory))
      }
      InfoLabeledContent(t("worktrees.branch-prefix"), info: t("worktrees.branch-prefix-info")) {
        TextField(
          t("worktrees.branch-prefix"),
          text: model.worktreeDefaultBinding(\.branchPrefix),
          prompt: Text(t("worktrees.prefix-none")),
        )
      }
      if let caption = model.workspace.worktreeDefaults.prefixExampleCaption {
        SettingsCaption(caption)
      }
      InfoLabeledContent(t("worktrees.hook-timeout"), info: t("worktrees.hook-timeout-info")) {
        SettingsNumberField(
          t("worktrees.hook-timeout"),
          value: model.settingBinding(
            \.projectHookTimeoutSeconds,
            write: model.setProjectHookTimeoutSeconds,
          ),
        )
        Text(t("worktrees.seconds"))
      }
    }

    SettingsGroup(t("worktrees.section-ports")) {
      InfoLabeledContent(
        t("worktrees.port-block-start"),
        info: t("worktrees.port-block-start-info"),
      ) {
        SettingsNumberField(
          t("worktrees.port-block-start"),
          value: model.settingBinding(\.portBlockStart, write: model.setPortBlockStart),
        )
      }
      InfoLabeledContent(
        t("worktrees.port-block-size"),
        info: t("worktrees.port-block-size-info"),
      ) {
        SettingsNumberField(
          t("worktrees.port-block-size"),
          value: model.settingBinding(\.portBlockSize, write: model.setPortBlockSize),
        )
        Text(t("worktrees.ports"))
      }
      if let caption = model.worktreesWithoutPortsCaption {
        SettingsCaption(caption)
      }
    }
  }

  @ViewBuilder private var existingWorktreeGroups: some View {
    SettingsGroup(t("worktrees.section-change-counts")) {
      InfoLabeledContent(t("worktrees.indicator"), info: t("worktrees.indicator-info")) {
        SettingsPopUp(
          label: t("worktrees.indicator"),
          selection: model.settingBinding(
            \.gitStatusIndicator,
            write: model.setGitStatusIndicator,
          ),
          title: model.workspace.gitStatusIndicator.displayName,
        ) {
          ForEach(GitStatusIndicator.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
      }
      InfoLabeledContent(t("worktrees.diff-algorithm"), info: t("worktrees.diff-algorithm-info")) {
        SettingsPopUp(
          label: t("worktrees.diff-algorithm"),
          selection: model.settingBinding(\.diffAlgorithm, write: model.setDiffAlgorithm),
          title: model.workspace.diffAlgorithm.displayName,
        ) {
          ForEach(DiffAlgorithm.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
      }
    }

    SettingsGroup(t("worktrees.section-removing")) {
      InfoToggle(
        t("worktrees.confirm-removal"),
        info: t("worktrees.confirm-removal-info"),
        isOn: model.settingBinding(
          \.confirmsWorktreeRemoval,
          write: model.setConfirmsWorktreeRemoval,
        ),
      )
      InfoToggle(
        t("worktrees.delete-branch"),
        info: t("worktrees.delete-branch-info"),
        isOn: model.settingBinding(
          \.deletesBranchWithWorktree,
          write: model.setDeletesBranchWithWorktree,
        ),
      )
      InfoToggle(
        t("worktrees.trash-removed"),
        info: t("worktrees.trash-removed-info"),
        isOn: model.settingBinding(
          \.trashesRemovedWorktrees,
          write: model.setTrashesRemovedWorktrees,
        ),
      )
    }

    SettingsGroup(t("worktrees.section-updating")) {
      InfoToggle(
        t("worktrees.send-conflicts"),
        info: t("worktrees.send-conflicts-info"),
        isOn: model.settingBinding(
          \.sendsConflictsToPreferredAgent,
          write: model.setSendsConflictsToPreferredAgent,
        ),
        isSwitchEnabled: model.hasPreferredAgent,
      )
      if let caption = model.preferredAgentNeededCaption {
        SettingsCaption(caption)
      }
    }
  }
}
