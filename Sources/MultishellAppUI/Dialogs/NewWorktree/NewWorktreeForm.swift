import MultishellAppCore
import MultishellCore
import SwiftUI

struct NewWorktreeForm: View {
  let model: AppModel

  @Environment(\.dismiss) private var dismiss
  @State private var draft: NewWorktreeDraft

  /// The project named, then where the rest comes from, one entry so a
  /// translation may order the two as its language does.
  private var subtitle: String {
    project.map { t("sheet.creates-from", $0.name) } ?? t("sheet.creates-from-chosen")
  }

  private var project: Project? {
    draft.projectID.flatMap(model.workspace.project)
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
          NewWorktreeFormNote(
            text: t("sheet.no-projects"),
            symbol: "folder.badge.plus",
            tint: .secondary,
          )
        } else {
          NewWorktreeProjectPicker(model: model, projectID: $draft.projectID)
          fields
          if draft.offersAgents {
            NewWorktreeAgentFields(model: model, draft: $draft)
          }
        }
      }
      .formStyle(.grouped)
      .disabled(draft.isCreating)
      .padding(.horizontal, -20)
      .padding(.top, 12)

      footer
    }
    .padding(20)
    .frame(width: UIMetrics.newWorktreeSheetWidth)
    .task(id: draft.projectID) {
      model.fitAgent(of: &draft)
      await loadBranches()
    }
    .onChange(of: model.workspace.projects.map(\.id)) { _, ids in
      draft.forgetProject(unlessIn: ids)
    }
    .onChange(of: draft.createsBranch) { _, _ in
      draft.fitBranchToMode(checkedOut: model.checkedOutBranches(for: draft))
    }
    .onChange(of: model.newTabAgentIDs) { _, offered in
      draft.offerAgents(offered)
    }
  }

  @ViewBuilder
  private var fields: some View {
    if project != nil, !draft.hasCommits {
      NewWorktreeFormNote(
        text: t("sheet.no-commits"),
        symbol: "exclamationmark.triangle.fill",
        tint: .yellow,
      )
    }

    Picker("", selection: $draft.createsBranch) {
      Text(t("sheet.new-branch")).tag(true)
      Text(t("sheet.existing-branch")).tag(false)
    }
    .segmentedAcrossRow()

    NewWorktreeBranchFields(
      draft: $draft,
      prefix: model.branchPrefix(for: draft),
      checkedOut: model.checkedOutBranches(for: draft),
    )

    LabeledContent(t("sheet.location")) {
      PathText(model.plannedLocation(for: draft))
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
      Button(draft.createTitle, action: create)
        .keyboardShortcut(.defaultAction)
        .disabled(!draft.canCreate(checkedOut: model.checkedOutBranches(for: draft)))
    }
    .padding(.top, 8)
  }

  /// `nil` leaves the project picker blank: the menu item with several
  /// projects and nothing selected has no project to assume.
  init(model: AppModel, initialProjectID: Project.ID?) {
    self.model = model
    _draft = State(initialValue: NewWorktreeDraft(projectID: initialProjectID))
  }

  /// Re-read per project, a late answer for another dropped by the draft.
  private func loadBranches() async {
    draft.beginLoading()
    guard let project, let read = await model.newWorktreeBranches(of: project) else { return }
    draft.finishLoading(project.id, with: read, checkedOut: model.checkedOutBranches(for: draft))
  }

  private func create() {
    guard let project else { return }
    draft.isCreating = true
    Task {
      await model.createWorktree(
        branch: draft.branch,
        basedOn: draft.startPoint,
        createsBranch: draft.createsBranch,
        in: project,
        firstTab: draft.firstTab,
      )
      dismiss()
    }
  }
}
