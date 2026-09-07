import MultishellAppCore
import SwiftUI

extension View {
  /// Asked when Cmd+W would close a pane or tab whose agent last reported
  /// that it is still working.
  func pendingCloseDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingClose?.title ?? "",
      isPresented: Binding(
        get: { model.pendingClose != nil }, set: { if !$0 { model.pendingClose = nil } }),
      titleVisibility: .visible,
      presenting: model.pendingClose
    ) { pending in
      Button(pending.buttonLabel, role: .destructive) { model.confirmPendingClose() }
      Button("Cancel", role: .cancel) { model.pendingClose = nil }
    } message: { _ in
      Text("An agent here reported that it is still working. Closing ends it.")
    }
  }
}
