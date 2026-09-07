import MultishellAppCore
import SwiftUI

extension View {
  /// The new-worktree sheet, opened by Cmd+N, the project row's + and the
  /// project menu. The request carries which project it starts on.
  func newWorktreeSheet(model: AppModel) -> some View {
    sheet(item: Bindable(model).newWorktreeRequest) {
      NewWorktreeSheet(model: model, initialProjectID: $0.projectID)
    }
  }
}
