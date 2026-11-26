import MultishellAppCore
import SwiftUI

extension View {
  /// Asked before an action picked again while its tab still runs something
  /// is restarted, which ends whatever runs there.
  func actionRestartAlert(model: AppModel) -> some View {
    destructiveAlert(model.pendingActionRestart) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: pending.message,
        choices: [pending.buttonLabel],
      )
    } answer: { pending, choice in
      model.answerActionRestart(pending, restarts: choice != nil)
    }
  }
}
