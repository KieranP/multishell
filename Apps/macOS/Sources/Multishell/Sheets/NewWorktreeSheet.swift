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
            ForEach(availableBranches, id: \.self, content: Text.init)
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
          .disabled(!canCreate)
      }
      .padding(.top, 8)
    }
    .padding(20)
    .frame(width: 520)
    .task {
      hasCommits = await model.hasCommits(project)
      (branches, remoteBranches) = await model.branches(of: project)
      baseBranch = await model.currentBranch(of: project)
      if !createBranch { branch = availableBranches.first ?? "" }
    }
    // The field and the picker share `branch`. Switching modes must not
    // carry a typed name into the picker, where it is not a choice, or an
    // existing branch's name back into the field, where it would be a
    // duplicate.
    .onChange(of: createBranch) { _, creating in
      if creating {
        if availableBranches.contains(branch) { branch = "" }
      } else if !availableBranches.contains(branch) {
        branch = availableBranches.first ?? ""
      }
    }
  }

  /// Local branches not already checked out somewhere: git refuses to check
  /// a branch out twice, so offering those would only produce an error.
  private var availableBranches: [String] {
    let checkedOut = Set(model.workspace.worktrees(of: project.id).compactMap(\.branch))
    return branches.filter { !checkedOut.contains($0) }
  }

  private var canCreate: Bool {
    guard hasCommits, !isCreating else { return false }
    return createBranch
      ? !branch.trimmingCharacters(in: .whitespaces).isEmpty
      : availableBranches.contains(branch)
  }

  /// The project's effective prefix, shown as fixed text so the user types
  /// only the part that varies and sees the full name they will get.
  private var prefix: String {
    model.workspace.worktreeSettings(for: project).branchPrefix
  }

  private var plannedPath: String {
    let name = branch.trimmingCharacters(in: .whitespaces)
    guard !name.isEmpty,
      let url = model.plannedPath(forBranch: name, createBranch: createBranch, in: project)
    else {
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
