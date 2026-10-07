import MultishellAppCore
import MultishellCore
import SwiftUI

/// The new-worktree sheet's project, blank until one is picked where the
/// sheet had none to assume.
struct NewWorktreeProjectPicker: View {
  let model: AppModel
  @Binding var projectID: Project.ID?

  var body: some View {
    let labels = NewWorktreeDraft.labels(for: model.workspace.projects)
    Picker(t("sheet.project"), selection: $projectID) {
      if projectID == nil {
        Text(t("sheet.choose-project")).tag(Project.ID?.none)
      }
      ForEach(model.workspace.projects) { candidate in
        label(candidate, text: labels[candidate.id] ?? candidate.name)
          .tag(Project.ID?.some(candidate.id))
      }
    }
  }

  /// The project's icon beside its name, so same-named projects are told
  /// apart by more than their path.
  private func label(_ project: Project, text: String) -> some View {
    Label(text, systemImage: model.effectiveSettings(for: project).iconKind.symbolName)
  }
}
