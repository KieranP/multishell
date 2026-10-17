import MultishellAppCore
import MultishellCore
import SwiftUI

/// The find bar over one pane or file tab, in Ghostty's shape: a well for the
/// text and three glyphs. Its text is the model's, per target; see terminals.md.
struct FindBar: View {
  /// What the bar takes when the pane has it; a narrower pane shrinks the
  /// well rather than drawing the bar over its neighbour.
  private static let width: CGFloat = 340
  private static let cornerRadius: CGFloat = 10
  private static let padding: CGFloat = 7

  let model: AppModel
  let targetID: FindTargetID
  let theme: Theme
  @FocusState private var isFieldFocused: Bool

  var body: some View {
    let metrics = model.metrics
    HStack(spacing: 4) {
      well(metrics)
      button("chevron.up", t("find.previous")) { model.findPrevious(in: targetID) }
      button("chevron.down", t("find.next")) { model.findNext(in: targetID) }
      button("xmark", t("find.close")) { model.closeFind(in: targetID) }
    }
    .padding(Self.padding)
    .frame(maxWidth: Self.width)
    .background(theme.findBar.background, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
    .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius).strokeBorder(theme.findBar.border))
    .padding(12)
    // A turn later, and only against a Cmd+F: a bar a worktree switch brings
    // back must not take the keyboard from the pane. See terminals.md.
    .task { claimField() }
    .onChange(of: model.findFieldRequests.contains(targetID)) { claimField() }
    .onDisappear { model.noteFindField(focused: false, of: targetID) }
  }

  /// The text sits in a well one step back from the panel, the way a
  /// terminal's own colour sits behind its chrome, with the count at its end.
  private func well(_ metrics: UIMetrics) -> some View {
    HStack(spacing: 6) {
      TextField("", text: model.findTextBinding(of: targetID))
        .textFieldStyle(.plain)
        .fieldPrompt(
          t("find.prompt"),
          isShown: model.findText(of: targetID).isEmpty,
          color: theme.color(.fieldTextSecondary, in: .findBar),
        )
        .font(metrics.font(size: metrics.bodySize))
        .foregroundStyle(theme.color(.fieldText, in: .findBar))
        .focused($isFieldFocused)
        .onChange(of: isFieldFocused) { model.noteFindField(focused: $1, of: targetID) }
        .onSubmit(submit)
        .onExitCommand { model.closeFind(in: targetID) }
      if let count = model.findMatchCount(of: targetID) {
        Text(count.text)
          .font(metrics.font(size: metrics.secondary).monospacedDigit())
          .foregroundStyle(theme.color(.fieldTextSecondary, in: .findBar))
          .fixedSize()
          .accessibilityLabel(count.spokenText)
      }
    }
    .padding(.horizontal, 10)
    .frame(height: metrics.findControlSize)
    .background(
      theme.color(.fieldBackground, in: .findBar),
      in: RoundedRectangle(cornerRadius: Self.cornerRadius - 3),
    )
    .overlay(
      RoundedRectangle(cornerRadius: Self.cornerRadius - 3).strokeBorder(
        theme.color(.fieldBorder, in: .findBar)
      )
    )
  }

  private func claimField() {
    if model.takeFindFieldRequest(targetID) { isFieldFocused = true }
  }

  /// Return steps down, Shift+Return up. The shift is read off the keyboard
  /// at the moment of the submit, `onSubmit` carrying no modifiers.
  private func submit() {
    if NSEvent.modifierFlags.contains(.shift) {
      model.findPrevious(in: targetID)
    } else {
      model.findNext(in: targetID)
    }
  }

  private func button(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
    FindBarButton(
      symbol: symbol,
      help: help,
      theme: theme,
      metrics: model.metrics,
      action: action,
    )
  }
}
