import MultishellCore
import SwiftUI

struct NewWorktreeSheet: View {
  let model: AppModel

  @Environment(\.dismiss) private var dismiss
  @State private var draft: NewWorktreeDraft

  /// `nil` leaves the project picker blank: the menu item with several
  /// projects and nothing selected has no project to assume.
  init(model: AppModel, initialProjectID: Project.ID?) {
    self.model = model
    _draft = State(initialValue: NewWorktreeDraft(projectID: initialProjectID))
  }

  private var project: Project? {
    draft.projectID.flatMap(model.workspace.project)
  }

  private var checkedOut: Set<String> {
    Set(project.map { model.workspace.worktrees(of: $0.id).compactMap(\.branch) } ?? [])
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("New Worktree")
        .font(.system(size: 15, weight: .semibold))
      Text(
        (project.map { "Creates a linked checkout of \($0.name)." }
          ?? "Creates a linked checkout of the chosen project.")
          + " Location and branch prefix come from project settings."
      )
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .padding(.top, 3)

      Form {
        if model.workspace.projects.isEmpty {
          Label {
            Text("No projects yet. Add a repository first (⌘O).")
              .font(.system(size: 12))
          } icon: {
            Image(systemName: "folder.badge.plus").foregroundStyle(.secondary)
          }
        } else {
          let labels = NewWorktreeDraft.labels(for: model.workspace.projects)
          Picker("Project:", selection: $draft.projectID) {
            if draft.projectID == nil {
              Text("Choose a project").tag(Project.ID?.none)
            }
            ForEach(model.workspace.projects) { candidate in
              pickerLabel(candidate, text: labels[candidate.id] ?? candidate.name)
                .tag(Project.ID?.some(candidate.id))
            }
          }
          fields
        }
      }
      .formStyle(.grouped)
      .disabled(draft.isCreating)
      .padding(.horizontal, -20)
      .padding(.top, 12)

      HStack(spacing: 8) {
        if draft.isCreating {
          ProgressView().controlSize(.small)
          Text(NewWorktreeDraft.progressText(for: model.worktreeCreationStep))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button("Create Worktree", action: create)
          .keyboardShortcut(.defaultAction)
          .disabled(!draft.canCreate(checkedOut: checkedOut))
      }
      .padding(.top, 8)
    }
    .padding(20)
    .frame(width: 520)
    // Re-read for each project the picker lands on. Picking another project
    // cancels this task but not the git call it is inside, so each result
    // is checked against the picker before it is used; the draft checks
    // again.
    .task(id: draft.projectID) {
      draft.beginLoading()
      guard let project else { return }
      let hasCommits = await model.hasCommits(project)
      guard !Task.isCancelled else { return }
      let (branches, remoteBranches) = await model.branches(of: project)
      guard !Task.isCancelled else { return }
      let current = await model.currentBranch(of: project)
      guard !Task.isCancelled else { return }
      draft.finishLoading(
        project.id, hasCommits: hasCommits, branches: branches, remoteBranches: remoteBranches,
        currentBranch: current, checkedOut: checkedOut)
    }
    .onChange(of: model.workspace.projects.map(\.id)) { _, ids in
      draft.projectsChanged(to: ids)
    }
    .onChange(of: draft.createBranch) { _, _ in
      draft.modeChanged(checkedOut: checkedOut)
    }
  }

  @ViewBuilder
  private var fields: some View {
    if project != nil, !draft.hasCommits {
      Label {
        Text(
          "This repository has no commits yet. A worktree needs a commit to start from; make the first one, then come back."
        )
        .font(.system(size: 12))
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
      }
    }

    Picker("", selection: $draft.createBranch) {
      Text("New branch").tag(true)
      Text("Existing branch").tag(false)
    }
    .pickerStyle(.segmented)
    .labelsHidden()

    if draft.createBranch {
      LabeledContent("Branch:") {
        HStack(spacing: 2) {
          if !prefix.isEmpty {
            Text(prefix)
              .font(.system(size: 13, design: .monospaced))
              .foregroundStyle(.secondary)
          }
          TextField("", text: $draft.branch, prompt: Text("feat/tabs"))
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
        }
      }
      Picker("Based on:", selection: $draft.baseBranch) {
        ForEach(draft.branches, id: \.self, content: Text.init)
        if !draft.remoteBranches.isEmpty {
          Divider()
          ForEach(draft.remoteBranches, id: \.self, content: Text.init)
        }
      }
    } else {
      // Local branches only. A large repository has hundreds of remote ones,
      // and a fresh clone with nothing local to pick is told so instead.
      let available = draft.availableBranches(checkedOut: checkedOut)
      if available.isEmpty, project != nil, draft.loadedProjectID == draft.projectID {
        Label {
          Text("Every local branch is already checked out. Switch to New branch to create one.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } icon: {
          Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
      } else {
        Picker("Branch:", selection: $draft.branch) {
          ForEach(available, id: \.self, content: Text.init)
        }
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

  /// The project's icon beside its name, so same-named projects are told
  /// apart by more than their path. A menu item draws text and a symbol
  /// image; an emoji rides along as text.
  @ViewBuilder
  private func pickerLabel(_ project: Project, text: String) -> some View {
    switch ProjectIcon.kind(of: project.settings.iconGlyph) {
    case .emoji(let emoji): Text("\(emoji)  \(text)")
    case .symbol(let name): Label(text, systemImage: name)
    case .folder: Label(text, systemImage: "folder")
    }
  }

  /// The project's effective prefix, shown as fixed text so the user types
  /// only the part that varies and sees the full name they will get.
  private var prefix: String {
    project.map { model.workspace.worktreeSettings(for: $0).branchPrefix } ?? ""
  }

  private var plannedPath: String {
    let name = draft.branch.trimmingCharacters(in: .whitespaces)
    guard let project, !name.isEmpty,
      let url = model.plannedPath(
        forBranch: name, createBranch: draft.createBranch, in: project)
    else {
      return "—"
    }
    return url.path
  }

  private func create() {
    guard let project else { return }
    draft.isCreating = true
    Task {
      await model.createWorktree(
        branch: draft.branch,
        basedOn: draft.startPoint,
        createBranch: draft.createBranch,
        in: project
      )
      dismiss()
    }
  }
}
