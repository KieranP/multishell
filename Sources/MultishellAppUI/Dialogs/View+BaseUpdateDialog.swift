import MultishellAppCore
import SwiftUI

extension View {
  /// Merge from Base or Rebase onto Base's question, where an agent works there
  /// or a rebase rewrites pushed commits.
  func baseUpdateDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingBaseUpdate?.title ?? "",
      isPresented: Binding(
        get: { model.pendingBaseUpdate != nil },
        set: { isPresented in
          if !isPresented, let pending = model.pendingBaseUpdate {
            model.answerBaseUpdate(pending, confirmed: false)
          }
        },
      ),
      titleVisibility: .visible,
      presenting: model.pendingBaseUpdate,
    ) { pending in
      Button(pending.confirmLabel) { model.answerBaseUpdate(pending, confirmed: true) }
        .keyboardShortcut(.defaultAction)
      Button(t("action.cancel"), role: .cancel) {
        model.answerBaseUpdate(pending, confirmed: false)
      }
    } message: { pending in
      Text(pending.message)
    }
  }
}
