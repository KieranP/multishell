import MultishellAppCore
import SwiftUI

extension View {
  /// The one-time question about the hooks a repository ships in its
  /// `.multishell.json`, asked when the user turns to that project.
  func sharedHooksTrustDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingSharedHooksTrust?.title ?? "",
      isPresented: Binding(
        get: { model.pendingSharedHooksTrust != nil },
        set: { if !$0 { model.pendingSharedHooksTrust = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingSharedHooksTrust
    ) { pending in
      Button(pending.trustLabel) { model.decideSharedHooks(pending, trusted: true) }
      Button(pending.declineLabel) { model.decideSharedHooks(pending, trusted: false) }
      // Escape: asked again next time, since nothing was decided.
      Button("Decide Later", role: .cancel) { model.pendingSharedHooksTrust = nil }
    } message: { pending in
      Text(pending.message)
    }
  }
}
