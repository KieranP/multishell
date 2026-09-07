import MultishellAppCore
import SwiftUI

extension View {
  /// Every error the model raises. The retry, where the error carries one,
  /// is destructive: the only one so far deletes a branch git refused to
  /// delete safely.
  func presentedErrorAlert(model: AppModel) -> some View {
    alert(item: Bindable(model).presentedError) { error in
      if let label = error.retryLabel, let retry = error.retry {
        Alert(
          title: Text(error.title),
          message: Text(error.message),
          primaryButton: .destructive(Text(label)) { Task { await retry() } },
          secondaryButton: .cancel()
        )
      } else {
        Alert(title: Text(error.title), message: Text(error.message))
      }
    }
  }
}
