import MultishellAppCore
import SwiftUI

/// The copy icon beside a value meant to be pasted elsewhere. The tick is
/// there because the clipboard gives no other sign it took.
struct CopyButton: View {
  let model: AppModel
  let text: String

  @State private var copied = false

  init(_ text: String, model: AppModel) {
    self.text = text
    self.model = model
  }

  var body: some View {
    GlyphButton(help: t("action.copy-value", text), action: copy) {
      Image(systemName: copied ? "checkmark" : "doc.on.doc")
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
    }
  }

  private func copy() {
    model.copyToClipboard(text)
    copied = true
    Task {
      try? await Task.sleep(for: .seconds(1.2))
      copied = false
    }
  }
}
