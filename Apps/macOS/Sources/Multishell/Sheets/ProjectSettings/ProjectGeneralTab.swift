import MultishellAppCore
import MultishellCore
import SwiftUI

struct ProjectGeneralTab: View {
  let model: AppModel
  let project: Project

  var body: some View {
    let worktrees = model.workspace.worktrees(of: project.id)
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

      ProjectIconSection(model: model, project: project)

      Section {
        HStack(spacing: 8) {
          Button("Export") { model.exportSharedSettings(for: project) }
          InfoButton(
            "Writes this project's worktree path, branch prefix, hooks, icon and what its worktrees open, as they are in effect, to \(SharedProjectSettings.fileName) at the repository root, for the team to commit, replacing one already there. Anyone who adds the repository gets them as defaults under their own; they are asked once before its hooks run."
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
}
