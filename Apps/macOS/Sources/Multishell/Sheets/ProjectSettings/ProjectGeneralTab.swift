import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectGeneralTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    let order = model.inherited(
      \.worktreeSortOrder, global: model.workspace.worktreeSortOrder, for: project)
    Form {
      Section {
        LabeledContent(t("project.repository")) {
          HStack {
            Text(project.path.path)
              .font(.system(size: 11, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.head)
            IconButton.reveal { model.revealInFileBrowser(project.path) }
              .controlSize(.small)
          }
        }
        LabeledContent(t("project.worktrees-label")) {
          HStack {
            Text(t("project.worktrees-discovered", worktrees.count))
            IconButton.refresh(help: t("project.refresh-from-git")) {
              Task { await model.refreshRequested(project) }
            }
            .controlSize(.small)
          }
        }
      }

      OverrideSection(
        model: model, project: project, setting: \.worktreeSortOrder,
        label: t("project.sort-worktrees"),
        info: t("project.sort-worktrees-info"),
        fallback: order.value
      ) { selection, isOverridden in
        Picker(t("worktrees.sort"), selection: selection) {
          ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .disabled(!isOverridden)
      } footer: {
        SettingsCaption(order.caption)
      }

      OverrideSection(
        model: model, project: project, setting: \.showsActiveWorktreesFirst,
        label: t("project.active-first"),
        info: t("project.active-first-info"),
        inherited: model.inherited(
          \.showsActiveWorktreesFirst, global: model.workspace.showsActiveWorktreesFirst,
          for: project))

      ProjectIconSection(model: model, project: project)

      Section {
        HStack(spacing: 8) {
          Button(t("action.export")) { model.exportSharedSettings(for: project) }
          InfoButton(t("project.export-info", SharedProjectSettings.fileName))
          Spacer()
          Button(t("actions.remove-project"), role: .destructive) {
            model.requestProjectRemoval(project, from: .settings)
          }
          InfoButton(t("project.remove-info"))
        }
      }
    }
    .formStyle(.grouped)
  }
}
