import MultishellAppCore
import MultishellCore
import SwiftUI

extension View {
  /// The confirmation removing a project asks for. Each window attaches this
  /// with its own `source`, and only the asking one presents.
  func projectRemovalDialog(model: AppModel, source: PendingProjectRemoval.Source) -> some View {
    confirmationDialog(
      model.pendingProjectRemoval?.title ?? "",
      isPresented: Binding(
        get: { model.pendingProjectRemoval?.source == source },
        set: { if !$0 { model.pendingProjectRemoval = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingProjectRemoval
    ) { pending in
      Button(t("dialog.remove-project"), role: .destructive) {
        model.pendingProjectRemoval = nil
        model.removeProject(pending.project)
      }
      Button(t("action.cancel"), role: .cancel) { model.pendingProjectRemoval = nil }
    } message: { pending in
      Text(model.projectRemovalMessage(for: pending.project))
    }
  }
}
