import MultishellAppCore
import SwiftUI

extension View {
  /// Create Pull Request's question before it pushes the branch.
  func branchPublishDialog(model: AppModel) -> some View {
    confirmationDialog(
      model.pendingBranchPublish?.title ?? "",
      isPresented: Binding(
        get: { model.pendingBranchPublish != nil },
        set: { isPresented in
          if !isPresented, let pending = model.pendingBranchPublish {
            model.answerBranchPublish(pending, publishes: false)
          }
        },
      ),
      titleVisibility: .visible,
      presenting: model.pendingBranchPublish,
    ) { pending in
      Button(pending.confirmLabel) { model.answerBranchPublish(pending, publishes: true) }
        .keyboardShortcut(.defaultAction)
      Button(t("action.cancel"), role: .cancel) {
        model.answerBranchPublish(pending, publishes: false)
      }
    } message: { pending in
      Text(pending.message)
    }
  }
}
