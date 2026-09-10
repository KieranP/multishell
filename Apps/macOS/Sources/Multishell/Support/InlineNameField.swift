import SwiftUI

/// A name typed in place: on a tab in the strip, and on a worktree's row.
///
/// Return commits, Escape leaves the name as it was, and leaving the field
/// commits. Both places want that same contract, and written out twice it
/// is the kind of thing that drifts once one of them is fixed, so the
/// draft, the focus and all three ways out live here.
///
/// The focus is this field's own. Kept on the strip it was one state for
/// every tab, and a blur arriving for the tab that had just lost the field
/// had to be told apart from the one that has it.
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
