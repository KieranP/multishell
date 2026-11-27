import SwiftUI

/// A changed command's or an action's keys on the control face; a click records new ones.
struct ShortcutKeysButton: View {
  let text: String
  let help: String
  let record: () -> Void

  var body: some View {
    Button(action: record) {
      Text(text)
        .shortcutKeysFace()
        .settingsControlFace()
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(help)
  }
}
