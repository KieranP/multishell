import MultishellAppCore
import SwiftUI

extension View {
  /// Create Pull Request's question before it pushes the branch.
  func branchPublishDialog(model: AppModel) -> some View {
    questionDialog(
      model.pendingBranchPublish,
      title: \.title,
      message: \.message,
      dismiss: { model.answerBranchPublish($0, publishes: false) },
      buttons: { pending in
        Button(pending.pushLabel) { model.answerBranchPublish(pending, publishes: true) }
          .keyboardShortcut(.defaultAction)
        Button(t("action.cancel"), role: .cancel) {
          model.answerBranchPublish(pending, publishes: false)
        }
      },
    )
  }
}
