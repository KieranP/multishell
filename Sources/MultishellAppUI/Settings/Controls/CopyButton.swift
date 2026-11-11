import MultishellAppCore
import SwiftUI

/// The copy icon beside a value meant to be pasted elsewhere. The tick is
/// there because the clipboard gives no other sign it took.
struct CopyButton: View {
  let model: AppModel
  let text: String

  @State private var showsCopiedTick = false
  /// Each click restarts the tick's time, `.task(id:)` cancelling the last.
  @State private var copyCount = 0

  var body: some View {
    PlainGlyphButton(help: t("action.copy-value", text), action: copy) {
      Image(systemName: showsCopiedTick ? "checkmark" : "doc.on.doc")
        .foregroundStyle(.secondary)
        .frame(
          width: UIMetrics.settingsGlyphButtonSide,
          height: UIMetrics.settingsGlyphButtonSide,
        )
        .accessibilityHidden(true)
    }
    .task(id: copyCount) { await hideTickWhenItsTimeIsUp() }
  }

  init(_ text: String, model: AppModel) {
    self.text = text
    self.model = model
  }

  private func copy() {
    model.copyToClipboard(text)
    showsCopiedTick = true
    copyCount += 1
  }

  private func hideTickWhenItsTimeIsUp() async {
    guard showsCopiedTick else { return }
    try? await Task.sleep(for: .seconds(1.2))
    if !Task.isCancelled { showsCopiedTick = false }
  }
}
