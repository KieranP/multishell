import MultishellAppCore
import SwiftUI

extension View {
  /// The confirmation removing a project asks for. Each window attaches this
  /// with its own `source`, and only the asking one presents.
  func projectRemovalDialog(model: AppModel, source: PendingProjectRemoval.Source) -> some View {
    let asked = model.pendingProjectRemoval.flatMap { $0.source == source ? $0 : nil }
    return destructiveAlert(asked) { pending in
      DestructiveAlert.make(
        title: pending.title,
        message: model.projectRemovalMessage(for: pending.project),
        choices: [t("dialog.remove-project")],
        cancel: t("action.cancel"))
    } answer: { pending, choice in
      model.pendingProjectRemoval = nil
      guard choice != nil else { return }
      model.removeProject(pending.project)
    }
  }
}
