import MultishellAppCore
import MultishellCore
import SwiftUI

/// Writing a comment under its lines: ⌘↩ adds it, Escape cancels. The draft
/// is the model's, so a tab hidden and shown again keeps it.
struct ReviewComposerCard: View {
  private static var fieldHeight: Double { 64 }

  let composer: ReviewComposer
  let theme: Theme
  let metrics: UIMetrics
  let noteDraft: (String) -> Void
  let commit: () -> Void
  let cancel: () -> Void
  let takesKeyboardOnAppear: Bool
  let onTookKeyboard: () -> Void

  @State private var draft: String

  private var canCommit: Bool { draft.trimmedOfAllWhitespaceOrNil != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(composer.label)
        .font(.system(size: metrics.caption, design: .monospaced))
        .foregroundStyle(theme.fileTab.textSecondary)
      // Plain text, so code in a comment reaches the agent with its quotes and dashes.
      MonospacedTextEditor(
        text: $draft,
        placeholder: t("review.composer-placeholder"),
        fontSize: metrics.secondary,
        fill: theme.fileTab.background,
        border: nil,
        minHeight: Self.fieldHeight,
        maxHeight: Self.fieldHeight,
        commit: { if canCommit { commitDraft() } },
        cancel: cancel,
        takesKeyboardOnAppear: takesKeyboardOnAppear,
        onTookKeyboard: onTookKeyboard,
        colors: PlainTextColors(
          text: theme.fileText,
          selection: theme.fileSelection,
          placeholder: theme.fileTab.textTertiary,
        ),
      )
      .accessibilityLabel(Text(t("review.composer-placeholder")))
      .onChange(of: draft) { _, text in noteDraft(text) }
      HStack(spacing: 8) {
        Spacer(minLength: 0)
        Button(t("action.cancel"), action: cancel)
          .buttonStyle(ThemedButtonStyle(fill: theme.fileTab.fill, text: theme.fileTab.text))
        Button(composer.commitTitle, action: commitDraft)
          .buttonStyle(
            ThemedButtonStyle(
              fill: theme.color(for: .attention, on: theme.fileTab),
              text: theme.fileTab.background,
            )
          )
          .disabled(!canCommit)
      }
      .controlSize(.small)
    }
    .reviewCardFrame(theme: theme)
  }

  init(
    composer: ReviewComposer,
    draft: String,
    theme: Theme,
    metrics: UIMetrics,
    noteDraft: @escaping (String) -> Void,
    commit: @escaping () -> Void,
    cancel: @escaping () -> Void,
    takesKeyboardOnAppear: Bool,
    onTookKeyboard: @escaping () -> Void,
  ) {
    self.composer = composer
    self.theme = theme
    self.metrics = metrics
    self.noteDraft = noteDraft
    self.commit = commit
    self.cancel = cancel
    self.takesKeyboardOnAppear = takesKeyboardOnAppear
    self.onTookKeyboard = onTookKeyboard
    _draft = State(initialValue: draft)
  }

  /// The model's copy of the draft follows a turn behind, so it is brought up to date first.
  private func commitDraft() {
    noteDraft(draft)
    commit()
  }
}
