import MultishellAppCore
import SwiftUI

extension View {
  /// Every error the model raises. A retry is destructive and offered beside
  /// a Cancel; an error with no retry gets SwiftUI's single dismiss.
  func presentedErrorAlert(model: AppModel, window: DialogWindow) -> some View {
    alert(
      model.presentedPlainError(in: window)?.title ?? "",
      isPresented: Binding(
        get: { model.presentedPlainError(in: window) != nil },
        set: { isPresented in
          if !isPresented, let error = model.presentedPlainError(in: window) {
            model.answerPresentedError(error, retrying: false)
          }
        },
      ),
      presenting: model.presentedPlainError(in: window),
    ) { _ in
    } message: { error in
      Text(error.message)
    }
    .destructiveAlert(model.presentedRetryableError(in: window)) { error in
      DestructiveAlert.make(
        title: error.title,
        message: error.message,
        choices: error.retry.map { [$0.label] } ?? [],
      )
    } answer: { error, choice in
      model.answerPresentedError(error, retrying: choice != nil)
    }
  }
}
