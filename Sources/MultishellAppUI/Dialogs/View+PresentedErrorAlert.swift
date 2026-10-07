import MultishellAppCore
import SwiftUI

extension View {
  /// Every error the model raises. A retry is destructive and offered beside
  /// a Cancel; an error with no retry gets SwiftUI's single dismiss.
  func presentedErrorAlert(model: AppModel) -> some View {
    alert(
      model.presentedPlainError?.title ?? "",
      isPresented: Binding(
        get: { model.presentedPlainError != nil },
        set: {
          if !$0, let error = model.presentedPlainError {
            model.answerPresentedError(error, retrying: false)
          }
        }),
      presenting: model.presentedPlainError
    ) { _ in
    } message: { error in
      Text(error.message)
    }
    .destructiveAlert(model.presentedRetryableError) { error in
      DestructiveAlert.make(
        title: error.title,
        message: error.message,
        choices: error.retry.map { [$0.label] } ?? [])
    } answer: { error, choice in
      model.answerPresentedError(error, retrying: choice != nil)
    }
  }
}
