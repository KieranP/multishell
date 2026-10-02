import MultishellAppCore
import SwiftUI

extension View {
  /// Every error the model raises. A retry is destructive and offered beside
  /// a Cancel; an error with no retry gets SwiftUI's single dismiss.
  func presentedErrorAlert(model: AppModel) -> some View {
    let retryable = model.presentedError.flatMap { $0.isRetryable ? $0 : nil }
    return alert(
      model.presentedError?.title ?? "",
      isPresented: Binding(
        get: { model.presentedError?.isRetryable == false },
        set: {
          if !$0, let error = model.presentedError {
            model.answerPresentedError(error, retrying: false)
          }
        }),
      presenting: model.presentedError
    ) { _ in
    } message: { error in
      Text(error.message)
    }
    .destructiveAlert(retryable) { error in
      DestructiveAlert.make(
        title: error.title,
        message: error.message,
        choices: error.retry.map { [$0.label] } ?? [],
        cancel: t("action.cancel"))
    } answer: { error, choice in
      model.answerPresentedError(error, retrying: choice != nil)
    }
  }
}
