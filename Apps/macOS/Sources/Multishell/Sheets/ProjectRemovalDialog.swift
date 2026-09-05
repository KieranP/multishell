import SwiftUI

extension View {
  /// The confirmation that removing a project asks for. Each window that
  /// can ask attaches this with its own `source`, and only the window the
  /// request came from presents it.
  func projectRemovalDialog(model: AppModel, source: PendingProjectRemoval.Source) -> some View {
    confirmationDialog(
      model.pendingProjectRemoval?.title ?? "",
      isPresented: Binding(
        get: { model.pendingProjectRemoval?.source == source },
        set: { if !$0 { model.pendingProjectRemoval = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingProjectRemoval
    ) { pending in
      Button("Remove Project", role: .destructive) {
        model.pendingProjectRemoval = nil
        model.removeProject(pending.project)
      }
      Button("Cancel", role: .cancel) { model.pendingProjectRemoval = nil }
    } message: { pending in
      Text(model.projectRemovalMessage(for: pending.project))
    }
  }
}
