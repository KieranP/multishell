import MultishellAppCore
import SwiftUI

extension View {
  /// The confirmation removing a project asks for. Each window attaches this
  /// with its own `window`, and only the asking one presents.
  func projectRemovalAlert(model: AppModel, window: DialogWindow) -> some View {
    destructiveAlert(model.pendingProjectRemoval(for: window)) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: model.projectRemovalMessage(for: pending.project),
        choices: [t("dialog.remove-project")],
      )
    } answer: { pending, choice in
      model.answerProjectRemoval(pending, confirmed: choice != nil)
    }
  }
}
