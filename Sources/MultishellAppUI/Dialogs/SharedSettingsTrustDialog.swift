import MultishellAppCore
import SwiftUI

extension View {
  /// The one-time question about what a repository's `.multishell.json`
  /// asks to run or read, asked when the user turns to that project.
  func sharedSettingsTrustDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingSharedSettingsTrust?.title ?? "",
      isPresented: Binding(
        get: { model.pendingSharedSettingsTrust != nil },
        set: { if !$0 { model.pendingSharedSettingsTrust = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingSharedSettingsTrust
    ) { pending in
      Button(pending.trustLabel) { model.decideSharedSettings(pending, trusted: true) }
      Button(pending.declineLabel) { model.decideSharedSettings(pending, trusted: false) }
        .keyboardShortcut(.defaultAction)
      // Escape: asked again next time, since nothing was decided.
      Button(t("dialog.decide-later"), role: .cancel) { model.pendingSharedSettingsTrust = nil }
    } message: { pending in
      Text(pending.message)
    }
  }
}
