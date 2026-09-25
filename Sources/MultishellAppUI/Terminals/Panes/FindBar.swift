import MultishellAppCore
import MultishellCore
import SwiftUI

/// The find bar over one pane, in Ghostty's shape: a well for the text and three
/// glyphs. Its text is the model's, per pane; see Docs/design/appearance.md.
struct FindBar: View {
  let model: AppModel
  let sessionID: TerminalSession.ID
  let theme: Theme
  @FocusState private var fieldFocused: Bool

  /// What the bar takes when the pane has it; a narrower pane shrinks the
  /// well rather than drawing the bar over its neighbour.
  private static let width: CGFloat = 340
  private static let corner: CGFloat = 10
  private static let inset: CGFloat = 7

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 4) {
      well(metrics)
      step("chevron.up", t("find.previous")) { model.findPrevious(in: sessionID) }
      step("chevron.down", t("find.next")) { model.findNext(in: sessionID) }
      step("xmark", t("find.close")) { model.closeFind(in: sessionID) }
    }
    .padding(Self.inset)
    .frame(maxWidth: Self.width)
    .background(theme.findPanelColor, in: RoundedRectangle(cornerRadius: Self.corner))
    .overlay(RoundedRectangle(cornerRadius: Self.corner).strokeBorder(theme.hairline))
    .padding(12)
    // A turn later, and only against a Cmd+F: a bar a worktree switch brings
    // back must not take the keyboard from the pane. See terminals.md.
    .task { claimField() }
    .onChange(of: model.findFieldRequests.contains(sessionID)) { claimField() }
    .onDisappear { model.noteFindField(focused: false, of: sessionID) }
  }

  /// The text sits in a well one step back from the panel, the way a
  /// terminal's own colour sits behind its chrome.
  private func well(_ metrics: UIMetrics) -> some View {
    TextField(t("find.prompt"), text: needle)
      .textFieldStyle(.plain)
      .font(.system(size: metrics.body))
      .foregroundStyle(theme.textPrimary)
      .focused($fieldFocused)
      .onChange(of: fieldFocused) { model.noteFindField(focused: $1, of: sessionID) }
      .onSubmit(submit)
      .onExitCommand { model.closeFind(in: sessionID) }
      .padding(.horizontal, 10)
      .frame(height: metrics.findControlSize)
      .background(theme.backgroundColor, in: RoundedRectangle(cornerRadius: Self.corner - 3))
      .overlay(RoundedRectangle(cornerRadius: Self.corner - 3).strokeBorder(theme.findWellBorder))
  }

  private func claimField() {
    if model.takeFindFieldRequest(sessionID) { fieldFocused = true }
  }

  /// Return steps down, Shift+Return up. The shift is read off the keyboard
  /// at the moment of the submit, `onSubmit` carrying no modifiers.
  private func submit() {
    if NSEvent.modifierFlags.contains(.shift) {
      model.findPrevious(in: sessionID)
    } else {
      model.findNext(in: sessionID)
    }
  }

  private var needle: Binding<String> {
    Binding(
      get: { model.findText(of: sessionID) }, set: { model.setFindText($0, of: sessionID) })
  }

  private func step(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
    StepButton(symbol: symbol, label: label, theme: theme, metrics: model.metrics, action: action)
  }
}

/// One glyph of the bar, lit on hover so the three read as buttons rather
/// than marks.
private struct StepButton: View {
  let symbol: String
  let label: String
  let theme: Theme
  let metrics: UIMetrics
  let action: () -> Void
  @State private var isHovered = false

  var body: some View {
    GlyphButton(help: label, action: action) {
      Image(systemName: symbol)
        .font(.system(size: metrics.body, weight: .medium))
        .foregroundStyle(isHovered ? theme.textPrimary : theme.textSecondary)
        .frame(width: metrics.findControlSize, height: metrics.findControlSize)
        .background(isHovered ? theme.rowHover : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
    .onHover { isHovered = $0 }
  }
}
