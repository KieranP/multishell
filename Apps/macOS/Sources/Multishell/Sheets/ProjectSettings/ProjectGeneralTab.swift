import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectGeneralTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
    let settings = model.settings(of: project)
    Form {
      Section {
        LabeledContent("Repository:") {
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
        LabeledContent("Worktrees:") {
          HStack {
            Text("\(worktrees.count) discovered")
            IconButton.refresh(help: "Refresh from git") {
              Task { await model.refreshRequested(project) }
            }
            .controlSize(.small)
          }
        }
      }

      Section {
        InfoToggle(
          "Override: Sort worktrees",
          info:
            "The order this project's worktree rows are listed in, whatever the global says. Created goes by when the worktree's directory was made, Last commit by the last commit on its branch. The main worktree, and the one on the default branch, stay at the top whichever order is chosen.",
          isOn: model.hasOverride(\.worktreeSortOrder, of: project, fallback: order.value))
        Picker(
          "Sort worktrees:",
          selection: model.overrideValue(\.worktreeSortOrder, of: project, fallback: order.value)
        ) {
          ForEach(WorktreeSortOrder.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .disabled(settings.worktreeSortOrder == nil)
      } footer: {
        if settings.worktreeSortOrder == nil { SettingsCaption(order.caption) }
      }

      Section {
        InfoToggle(
          "Override: Show active at the top",
          info:
            "Whether this project's worktrees with a terminal open, or with a state an agent or a hook reported, are listed above the rest, whatever the global says. Each group is then in the order above.",
          isOn: model.hasOverride(
            \.showsActiveWorktreesFirst, of: project, fallback: activeFirst.value)
        )
        Toggle(
          "Show active at the top",
          isOn: model.overrideValue(
            \.showsActiveWorktreesFirst, of: project, fallback: activeFirst.value)
        )
        .disabled(settings.showsActiveWorktreesFirst == nil)
      } footer: {
        if settings.showsActiveWorktreesFirst == nil { SettingsCaption(activeFirst.caption) }
      }

      ProjectIconSection(model: model, project: project)

      Section {
        HStack(spacing: 8) {
          Button("Export") { model.exportSharedSettings(for: project) }
          InfoButton(
            "Writes this project's worktree path, branch prefix, hooks, the files new worktrees are linked to or given, icon, what its worktrees open and the order they are listed in, as they are in effect, to \(SharedProjectSettings.fileName) at the repository root, for the team to commit, replacing one already there. Anyone who adds the repository gets them as defaults under their own; they are asked once before its hooks run."
          )
          Spacer()
          Button("Remove Project…", role: .destructive) {
            model.requestProjectRemoval(project, from: .settings)
          }
          InfoButton(
            "Takes the project out of the sidebar and closes its terminals, after asking. Nothing on disk is touched."
          )
        }
      }
    }
    .formStyle(.grouped)
  }

  /// What is in force while the project overrides neither: the
  /// repository's `.multishell.json` where it says, else the user's global.
  private var order: InheritedSetting<WorktreeSortOrder> {
    model.inherited(
      \.worktreeSortOrder, global: model.workspace.worktreeSortOrder, for: project)
  }

  private var activeFirst: InheritedFlag {
    model.inherited(
      \.showsActiveWorktreesFirst, global: model.workspace.showsActiveWorktreesFirst,
      for: project)
  }
}
