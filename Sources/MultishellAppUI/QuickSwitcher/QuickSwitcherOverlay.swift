import AppKit
import MultishellAppCore
import MultishellCore
import SwiftUI

/// The quick switcher over the whole window, drawn as the find bar is, a
/// panel lifted under a hairline with the field in a well. See quick-switcher.md.
struct QuickSwitcherOverlay: View {
  let model: AppModel
  let state: QuickSwitcherState
  /// An input method's text still being composed, which the prompt must not
  /// overlay though the model's text is still empty.
  @State private var isComposing = false

  var body: some View {
    let theme = model.currentTheme
    let metrics = model.metrics
    let palette = theme.quickSwitcher
    let results = model.quickSwitcherResults
    ZStack(alignment: .top) {
      // A click anywhere outside the panel closes it, as Escape does.
      Color.clear
        .contentShape(.rect)
        .onTapGesture { model.closeQuickSwitcher() }
        .accessibilityHidden(true)
      VStack(spacing: 0) {
        field(palette: palette, metrics: metrics)
        QuickSwitcherScopeBar(
          scope: state.scope,
          palette: palette,
          metrics: metrics,
          setScope: model.setQuickSwitcherScope,
        )
        list(results, theme: theme, metrics: metrics)
          .hairline(.top, palette)
        QuickSwitcherFooter(palette: palette, metrics: metrics)
          .hairline(.top, palette)
      }
      .frame(maxWidth: UIMetrics.quickSwitcherWidth)
      .floatingPanel(palette.background, border: palette.border)
      .padding(.horizontal, 24)
      .padding(.top, metrics.quickSwitcherTopInset)
      .padding(.bottom, UIMetrics.quickSwitcherBottomInset)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(t("quick-switcher.label"))
    }
  }

  private func field(palette: AreaPalette, metrics: UIMetrics) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: metrics.glyph))
        .foregroundStyle(palette.color(.fieldTextSecondary))
        .accessibilityHidden(true)
      QuickSwitcherTextField(
        text: state.text,
        font: metrics.appKitFont(size: metrics.quickSwitcherFieldFontSize),
        color: NSColor(palette.color(.fieldText)),
        handlers: QuickSwitcherFieldHandlers(
          setText: { text in
            model.setQuickSwitcherText(text)
            return model.quickSwitcher?.text ?? text
          },
          onCompose: { isComposing = $0 },
          move: model.moveQuickSwitcherSelection,
          stepScope: model.stepQuickSwitcherScope,
          onBackspaceWhenEmpty: model.backspaceInEmptyQuickSwitcherField,
          choose: model.chooseSelectedQuickSwitcherRow,
          close: model.closeQuickSwitcher,
          onEndEditing: model.noteQuickSwitcherFieldEndedEditing,
        ),
      )
      .fieldPrompt(
        state.scope.prompt,
        isShown: state.text.isEmpty && !isComposing,
        color: palette.color(.fieldTextSecondary),
      )
      .font(metrics.font(size: metrics.quickSwitcherFieldFontSize))
    }
    .padding(.horizontal, UIMetrics.quickSwitcherSideInset)
    .frame(height: metrics.quickSwitcherFieldHeight)
    .floatingPanelWell(palette.color(.fieldBackground), border: palette.color(.fieldBorder))
    .padding([.horizontal, .top], 8)
  }

  @ViewBuilder
  private func list(
    _ results: QuickSwitcherResults,
    theme: Theme,
    metrics: UIMetrics,
  ) -> some View {
    if let reason = results.emptyReason {
      Text(emptyText(reason))
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(theme.quickSwitcher.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    } else {
      QuickSwitcherList(
        results: results,
        theme: theme,
        metrics: metrics,
        choose: { model.chooseQuickSwitcherRow($0) },
        point: { model.pointQuickSwitcherAt($0) },
        forgetLostSelection: { model.forgetLostQuickSwitcherSelection() },
      )
      .frame(maxHeight: min(metrics.quickSwitcherListHeight, contentHeight(of: results)))
    }
  }

  private func contentHeight(of results: QuickSwitcherResults) -> Double {
    model.metrics.quickSwitcherListContentHeight(
      sections: results.sections.count,
      rows: results.sections.reduce(0) { $0 + $1.items.count },
    )
  }

  private func emptyText(_ reason: QuickSwitcherEmptyReason) -> String {
    switch reason {
    case .noMatch: t("quick-switcher.no-match", state.text)
    case .nothingToList: t("quick-switcher.empty")
    case .readingFiles: t("quick-switcher.reading-files")
    }
  }
}
