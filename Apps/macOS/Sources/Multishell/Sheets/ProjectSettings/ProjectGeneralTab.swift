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
          isOn: overrides(\.worktreeSortOrder, default: order.value))
        Picker("Sort worktrees:", selection: sortOrder(under: order.value)) {
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
          isOn: overrides(\.showsActiveWorktreesFirst, default: activeFirst.value))
        Toggle("Show active at the top", isOn: value(under: activeFirst.value))
          .disabled(settings.showsActiveWorktreesFirst == nil)
      } footer: {
        if settings.showsActiveWorktreesFirst == nil { SettingsCaption(activeFirst.caption) }
      }

      ProjectIconSection(model: model, project: project)

      Section {
        HStack(spacing: 8) {
          Button("Export") { model.exportSharedSettings(for: project) }
          InfoButton(
            "Writes this project's worktree path, branch prefix, hooks, icon, what its worktrees open and the order they are listed in, as they are in effect, to \(SharedProjectSettings.fileName) at the repository root, for the team to commit, replacing one already there. Anyone who adds the repository gets them as defaults under their own; they are asked once before its hooks run."
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
  /// The forms seed an override from this rather than from the global, or
  /// turning one on would replace what the project was doing with a value
  /// nobody was using.
  private var order: InheritedSetting<WorktreeSortOrder> {
    model.inherited(
      \.worktreeSortOrder, global: model.workspace.worktreeSortOrder, for: project)
  }

  private var activeFirst: InheritedFlag {
    model.inherited(
      \.showsActiveWorktreesFirst, global: model.workspace.showsActiveWorktreesFirst,
      for: project)
  }

  /// Turning an override on seeds it with what was already in force;
  /// turning it off returns to following it.
  private func overrides<Value: Equatable & Sendable>(
    _ keyPath: WritableKeyPath<ProjectSettings, Value?>, default inForce: Value
  ) -> Binding<Bool> {
    let source = model.setting(keyPath, of: project)
    return Binding(
      get: { source.wrappedValue != nil },
      set: { on in source.wrappedValue = on ? inForce : nil }
    )
  }

  /// The overridden order, showing what is in force while it is not
  /// overridden, so the disabled picker reads as what the sidebar is doing.
  private func sortOrder(under inForce: WorktreeSortOrder) -> Binding<WorktreeSortOrder> {
    let source = model.setting(\.worktreeSortOrder, of: project)
    return Binding(get: { source.wrappedValue ?? inForce }, set: { source.wrappedValue = $0 })
  }

  private func value(under inForce: Bool) -> Binding<Bool> {
    let source = model.setting(\.showsActiveWorktreesFirst, of: project)
    return Binding(get: { source.wrappedValue ?? inForce }, set: { source.wrappedValue = $0 })
  }
}
