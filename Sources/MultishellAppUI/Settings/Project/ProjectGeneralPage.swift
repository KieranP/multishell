import MultishellAppCore
import MultishellCore
import SwiftUI

/// The project's repository, how the sidebar lists its worktrees, its icon,
/// and sharing or removing it.
struct ProjectGeneralPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    SettingsForm {
      SettingsGroup {
        LabeledContent(t("project.repository")) {
          HStack {
            PathText(project.path.path)
            SettingsSymbolButton.reveal { model.revealInFileBrowser(project.path) }
          }
        }
        LabeledContent(t("project.worktrees-label")) {
          HStack {
            Text(t("project.worktrees-discovered", worktrees.count))
            SettingsSymbolButton.refresh(help: t("project.refresh-from-git")) {
              Task { await model.refreshWorktreesOnRequest(of: project) }
            }
          }
        }
      }

      OverrideTable {
        OverrideRow(
          model: model,
          project: project,
          setting: .worktreeSortOrder,
          global: model.workspace.worktreeSortOrder,
          label: t("project.sort-worktrees"),
          info: t("project.sort-worktrees-info"),
          globalValue: \.globalValue,
        ) { selection in
          SettingsPopUp(
            label: t("project.sort-worktrees"),
            selection: selection,
            title: selection.wrappedValue.displayName,
          ) {
            ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
          }
        }
        OverrideRow(
          model: model,
          project: project,
          setting: .showsActiveWorktreesFirst,
          globalSetting: \.showsActiveWorktreesFirst,
          label: t("project.active-first"),
          info: t("project.active-first-info"),
          globalSection: nil,
        )
      }

      ProjectIconSection(model: model, project: project)

      SettingsGroup {
        HStack(spacing: 8) {
          Button(t("action.export")) { Task { await model.exportSharedSettings(for: project) } }
          InfoButton(t("project.export-info", SharedProjectSettings.fileName))
          Spacer()
          Button(t("action.remove-project"), role: .destructive) {
            model.requestProjectRemoval(project, from: .settings)
          }
          InfoButton(t("project.remove-info"))
        }
      }
    }
  }
}
