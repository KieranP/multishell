import MultishellAppCore
import MultishellCore
import SwiftUI

extension View {
  /// Every error the model raises. A retry is destructive and offered beside
  /// a Cancel; an error with no retry gets SwiftUI's single dismiss.
  func presentedErrorAlert(model: AppModel) -> some View {
    alert(
      model.presentedError?.title ?? "",
      isPresented: Binding(
        get: { model.presentedError != nil }, set: { if !$0 { model.presentedError = nil } }),
      presenting: model.presentedError
    ) { error in
      if let label = error.retryLabel, let retry = error.retry {
        Button(label, role: .destructive) { Task { await retry() } }
        Button(t("action.cancel"), role: .cancel) {}
      }
    } message: { error in
      Text(error.message)
    }
  }
}
