import MultishellCore
import SwiftUI

struct NewWorktreeSheet: View {
  let model: AppModel
  let project: Project

  @Environment(\.dismiss) private var dismiss
  @State private var branch = ""
  @State private var createBranch = true
  @State private var baseBranch = ""
  @State private var branches: [String] = []
  @State private var remoteBranches: [String] = []
  @State private var hasCommits = true
  @State private var isCreating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("New Worktree")
        .font(.system(size: 15, weight: .semibold))
      Text(
        "Creates a linked checkout of \(project.name). Location and branch prefix come from project settings."
      )
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .padding(.top, 3)

      Form {
        if !hasCommits {
          Label {
            Text(
              "This repository has no commits yet. A worktree needs a commit to start from; make the first one, then come back."
            )
            .font(.system(size: 12))
          } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
          }
        }

        Picker("", selection: $createBranch) {
          Text("New branch").tag(true)
          Text("Existing branch").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()

        if createBranch {
          LabeledContent("Branch:") {
            HStack(spacing: 2) {
              if !prefix.isEmpty {
                Text(prefix)
                  .font(.system(size: 13, design: .monospaced))
                  .foregroundStyle(.secondary)
              }
              TextField("", text: $branch, prompt: Text("feat/tabs"))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
            }
          }
          Picker("Based on:", selection: $baseBranch) {
            ForEach(branches, id: \.self, content: Text.init)
            if !remoteBranches.isEmpty {
              Divider()
              ForEach(remoteBranches, id: \.self, content: Text.init)
            }
          }
        } else {
          Picker("Branch:", selection: $branch) {
            ForEach(branches, id: \.self, content: Text.init)
          }
        }

        LabeledContent("Location:") {
          Text(plannedPath)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.head)
        }
      }
      .formStyle(.grouped)
      .padding(.horizontal, -20)
      .padding(.top, 12)

      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }
        Button("Create Worktree", action: create)
          .keyboardShortcut(.defaultAction)
          .disabled(
            branch.trimmingCharacters(in: .whitespaces).isEmpty || isCreating || !hasCommits)
      }
      .padding(.top, 8)
    }
    .padding(20)
    .frame(width: 520)
    .task {
      hasCommits = await model.hasCommits(project)
      (branches, remoteBranches) = await model.branches(of: project)
      baseBranch = await model.currentBranch(of: project)
      if !createBranch { branch = branches.first ?? "" }
    }
  }

  /// The project's effective prefix, shown as fixed text so the user types
  /// only the part that varies and sees the full name they will get.
  private var prefix: String {
    model.workspace.worktreeSettings(for: project).branchPrefix
  }

  private var plannedPath: String {
    let name = branch.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty, let url = model.plannedPath(forBranch: name, in: project) else {
      return "—"
    }
    return url.path
  }

  private func create() {
    isCreating = true
    Task {
      await model.createWorktree(
        branch: branch,
        basedOn: createBranch ? baseBranch : nil,
        createBranch: createBranch,
        in: project
      )
      dismiss()
    }
  }
}
