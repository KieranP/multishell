import MultishellCore
import SwiftUI

struct EmptyStateView: View {
  let hasProjects: Bool
  let theme: Theme
  let addProject: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      Image(systemName: "arrow.trianglehead.branch")
        .font(.system(size: 40, weight: .light))
        .foregroundStyle(theme.textTertiary)

      Text(hasProjects ? "Select a worktree" : "Add a project to get started")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(theme.textPrimary)
        .padding(.top, 20)

      Text(
        hasProjects
          ? "Pick one in the sidebar and its terminals open here."
          : "Point Multishell at a git repository. Its worktrees appear in the sidebar, and each one gets its own set of terminals."
      )
      .font(.system(size: 13))
      .foregroundStyle(theme.textSecondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 380)
      .padding(.top, 6)

      if !hasProjects {
        Button(action: addProject) {
          Label("Add Project…", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 22)
      }
    }
    .padding(48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
