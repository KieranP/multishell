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
    project.map { model.workspace.checkedOutBranches(of: $0.id) } ?? []
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
          FormNote(text: t("sheet.no-projects"), symbol: "folder.badge.plus", tint: .secondary)
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

      footer
    }
    .padding(20)
    .frame(width: 520)
    .task(id: draft.projectID) { await loadBranches() }
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
      FormNote(
        text: t("sheet.no-commits"), symbol: "exclamationmark.triangle.fill", tint: .yellow)
    }

    Picker("", selection: $draft.createBranch) {
      Text(t("sheet.new-branch")).tag(true)
      Text(t("sheet.existing-branch")).tag(false)
    }
    .segmentedAcrossRow()

    if draft.createBranch { newBranchFields } else { existingBranchFields }

    LabeledContent(t("sheet.location")) {
      PathText(model.plannedLocation(for: draft))
    }
  }

  @ViewBuilder
  private var newBranchFields: some View {
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
    if draft.branchNameIsRefused {
      FormNote(
        text: t("sheet.branch-refused"), symbol: "exclamationmark.triangle.fill", tint: .yellow)
    }
    Picker(t("sheet.based-on"), selection: $draft.baseBranch) {
      ForEach(draft.localBranches, id: \.self, content: Text.init)
      if !draft.remoteBranches.isEmpty {
        Divider()
        ForEach(draft.remoteBranches, id: \.self, content: Text.init)
      }
    }
  }

  @ViewBuilder
  private var existingBranchFields: some View {
    // Local branches only. A large repository has hundreds of remote ones,
    // and a fresh clone with nothing local to pick is told so instead.
    if draft.showsAllCheckedOutNote(checkedOut: checkedOut) {
      FormNote(
        text: t("sheet.all-branches-checked-out"), symbol: "info.circle", tint: .secondary,
        dimsText: true)
    } else {
      Picker(t("sheet.branch"), selection: $draft.branch) {
        ForEach(draft.availableBranches(checkedOut: checkedOut), id: \.self, content: Text.init)
      }
    }
  }

  private var footer: some View {
    HStack(spacing: 8) {
      if draft.isCreating {
        ProgressView().controlSize(.small)
        Text(NewWorktreeDraft.progressText(for: model.worktreeCreationStep))
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      // While a create runs, Cancel ends its pre-create hook or git itself.
      Button(t("action.cancel"), role: .cancel) {
        if draft.isCreating { model.cancelWorktreeCreation() } else { dismiss() }
      }
      .keyboardShortcut(.cancelAction)
      Button(t("sheet.create-worktree"), action: create)
        .keyboardShortcut(.defaultAction)
        .disabled(!draft.canCreate(checkedOut: checkedOut))
    }
    .padding(.top, 8)
  }

  /// Re-read per project, a late answer for another dropped by the draft.
  private func loadBranches() async {
    draft.beginLoading()
    guard let project, let read = await model.newWorktreeBranches(of: project) else { return }
    draft.finishLoading(project.id, with: read, checkedOut: checkedOut)
  }

  /// The project's icon beside its name, so same-named projects are told
  /// apart by more than their path.
  private func pickerLabel(_ project: Project, text: String) -> some View {
    Label(text, systemImage: model.effectiveSettings(for: project).iconKind.symbolName)
  }

  /// The project's effective prefix, shown as fixed text so the user types
  /// only the part that varies and sees the full name they will get.
  private var prefix: String {
    project.map { model.worktreeSettings(for: $0).branchPrefix } ?? ""
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

extension View {
  /// The new-worktree sheet, opened by Cmd+N, the project row's + and the
  /// project menu. The request carries which project it starts on.
  func newWorktreeSheet(model: AppModel) -> some View {
    sheet(item: Bindable(model).newWorktreeRequest) {
      NewWorktreeSheet(model: model, initialProjectID: $0.projectID)
    }
  }
}
