import MultishellAppCore
import MultishellCore
import SwiftUI

/// An own action's name, written back on Return or on leaving the field: a
/// keystroke can pass through another action's name, which a save would refuse.
struct ActionNameField: View {
  let model: AppModel
  let project: Project
  let name: String
  let index: Int

  @State private var draft = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField(t("actions.name"), text: $draft)
      .labelsHidden()
      .focused($isFocused)
      .onSubmit(commit)
      .onChange(of: isFocused) { _, focused in
        if !focused { commit() }
      }
      .onChange(of: name, initial: true) { _, stored in
        if !isFocused { draft = stored }
      }
  }

  private func commit() {
    draft = model.setActionName(draft, at: index, in: project) ?? name
  }
}
