import MultishellAppCore
import MultishellCore
import SwiftUI

extension View {
  /// Every error the model raises. The retry, where the error carries one,
  /// is destructive: the only one so far deletes a branch git refused to
  /// delete safely, so it is offered beside a Cancel rather than on its own.
  /// An error with no retry gets the single dismiss button SwiftUI supplies.
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
