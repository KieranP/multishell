import MultishellAppCore
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

  /// One sentence naming the project, then where the rest comes from.
  private var subtitle: String {
    let opening =
      project.map { t("sheet.creates-from", $0.name) } ?? t("sheet.creates-from-chosen")
    return opening + " " + t("sheet.location-note")
  }

  private var project: Project? {
    draft.projectID.flatMap(model.workspace.project)
  }

  private var checkedOut: Set<String> {
    Set(project.map { model.workspace.worktrees(of: $0.id).compactMap(\.branch) } ?? [])
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(t("sheet.new-worktree"))
        .font(.system(size: 15, weight: .semibold))
      Text(subtitle)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .padding(.top, 3)

      Form {
        if model.workspace.projects.isEmpty {
          Label {
            Text(t("sheet.no-projects"))
              .font(.system(size: 12))
          } icon: {
            Image(systemName: "folder.badge.plus").foregroundStyle(.secondary)
          }
        } else {
          let labels = NewWorktreeDraft.labels(for: model.workspace.projects)
          Picker(t("sheet.project"), selection: $draft.projectID) {
            if draft.projectID == nil {
              Text(t("sheet.choose-project")).tag(Project.ID?.none)
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
        // While a create runs, Cancel stops its pre-create hook and the
        // sheet closes when the create returns; nothing is created. Once
        // git itself is running there is nothing to stop, so no button.
        Button(t("action.cancel"), role: .cancel) {
          if draft.isCreating { model.cancelWorktreeCreation() } else { dismiss() }
        }
        .keyboardShortcut(.cancelAction)
        .disabled(draft.isCreating && model.worktreeCreationStep != .preCreateHook)
        Button(t("sheet.create-worktree"), action: create)
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
        Text(t("sheet.no-commits"))
          .font(.system(size: 12))
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
      }
    }

    Picker("", selection: $draft.createBranch) {
      Text(t("sheet.new-branch")).tag(true)
      Text(t("sheet.existing-branch")).tag(false)
    }
    .pickerStyle(.segmented)
    .labelsHidden()

    if draft.createBranch {
      LabeledContent(t("sheet.branch")) {
        HStack(spacing: 2) {
          if !prefix.isEmpty {
            Text(prefix)
              .font(.system(size: 13, design: .monospaced))
              .foregroundStyle(.secondary)
          }
          TextField("", text: $draft.branch, prompt: Text(t("sheet.branch-prompt")))
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
        }
      }
      Picker(t("sheet.based-on"), selection: $draft.baseBranch) {
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
          Text(t("sheet.all-branches-checked-out"))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        } icon: {
          Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
      } else {
        Picker(t("sheet.branch"), selection: $draft.branch) {
          ForEach(available, id: \.self, content: Text.init)
        }
      }
    }

    LabeledContent(t("sheet.location")) {
      Text(plannedPath)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.head)
    }
  }

  /// The project's icon beside its name, so same-named projects are told
  /// apart by more than their path.
  private func pickerLabel(_ project: Project, text: String) -> some View {
    Label(
      text,
      systemImage: ProjectIcon.kind(of: model.effectiveSettings(for: project).iconGlyph).symbolName)
  }

  /// The project's effective prefix, shown as fixed text so the user types
  /// only the part that varies and sees the full name they will get.
  private var prefix: String {
    project.map { model.worktreeSettings(for: $0).branchPrefix } ?? ""
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
