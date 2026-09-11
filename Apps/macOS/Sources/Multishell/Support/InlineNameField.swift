import SwiftUI

/// A name typed in place, on a tab or a worktree's row: Return and blur
/// commit, Escape does not. The focus is this field's own.
struct InlineNameField: View {
  /// What the field opens with, seeded when it appears rather than by
  /// whoever put it on screen.
  let initial: String
  let prompt: String
  let font: Font
  let color: Color
  let commit: (String) -> Void
  let cancel: () -> Void

  @State private var draft = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField(prompt, text: $draft)
      .textFieldStyle(.plain)
      .font(font)
      .foregroundStyle(color)
      .focused($isFocused)
      .onSubmit { commit(draft) }
      .onExitCommand(perform: cancel)
      .onAppear {
        draft = initial
        isFocused = true
      }
      .onChange(of: isFocused) { _, focused in
        if !focused { commit(draft) }
      }
  }
}
