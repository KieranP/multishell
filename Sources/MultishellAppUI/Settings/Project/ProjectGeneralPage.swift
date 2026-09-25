import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectGeneralPage: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    Form {
      Section {
        LabeledContent(t("project.repository")) {
          HStack {
            PathText(project.path.path)
            SymbolButton.reveal { model.revealInFileBrowser(project.path) }
              .controlSize(.small)
          }
        }
        LabeledContent(t("project.worktrees-label")) {
          HStack {
            Text(t("project.worktrees-discovered", worktrees.count))
            SymbolButton.refresh(help: t("project.refresh-from-git")) {
              Task { await model.refreshOnRequest(project) }
            }
            .controlSize(.small)
          }
        }
      }

      OverrideSection(
        model: model, project: project, setting: .worktreeSortOrder,
        global: model.workspace.worktreeSortOrder,
        label: t("project.sort-worktrees"),
        info: t("project.sort-worktrees-info")
      ) { selection, isOverridden, _ in
        Picker(t("worktrees.sort"), selection: selection) {
          ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .disabled(!isOverridden)
      } footer: { order in
        SettingsCaption(order.caption)
      }

      OverrideSection(
        model: model, project: project, setting: .showsActiveWorktreesFirst,
        global: \.showsActiveWorktreesFirst,
        label: t("project.active-first"),
        info: t("project.active-first-info"))

      ProjectIconSection(model: model, project: project)

      Section {
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
    .formStyle(.grouped)
  }
}
