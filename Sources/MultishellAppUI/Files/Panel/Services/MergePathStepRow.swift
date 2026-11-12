import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One step of the merge path: its glyph on the rail, its title and hint,
/// and for the checks step every check under it.
struct MergePathStepRow: View {
  private static let railWidth = 1.5
  /// Between the glyph and the rail under it.
  private static let railGap = 3.0
  /// Under each step, the rail running on through it.
  private static let stepSpacing = 14.0
  /// The rail under a passed step, faded so the glyphs on it stay first.
  private static let passedRailOpacity = 0.55

  let model: AppModel
  let path: MergePath
  let step: MergePath.Step
  let base: String
  let host: String
  let theme: Theme
  @Binding var showsChecks: Bool

  var body: some View {
    let metrics = model.metrics
    HStack(alignment: .top, spacing: UIMetrics.servicePageGlyphSpacing) {
      VStack(spacing: Self.railGap) {
        glyph
          .frame(width: metrics.serviceGlyphSize, height: metrics.serviceGlyphSize)
          .padding(.top, metrics.mergePathGlyphDrop)
        Capsule()
          .fill(railColor)
          .frame(width: Self.railWidth)
          .frame(maxHeight: .infinity)
      }
      VStack(alignment: .leading, spacing: 0) {
        MergePathWords(
          hint: path.hint(of: step, base: base, host: host),
          metrics: metrics,
          theme: theme,
        ) {
          heading
        }
        if step.kind == .checks, showsChecks, let checks = path.checks {
          VStack(spacing: 0) {
            ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
              PullRequestCheckRow(model: model, check: check, theme: theme)
            }
          }
          .padding(.top, 7)
        }
      }
      .padding(.bottom, Self.stepSpacing)
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, UIMetrics.servicePageSideInset)
  }

  @ViewBuilder private var glyph: some View {
    let metrics = model.metrics
    if step.warnsOfConflicts {
      WarningShape()
        .stroke(
          theme.color(for: PullRequestMark.Corner.conflicts),
          style: StrokeStyle(
            lineWidth: UIMetrics.statusGlyphLineWidth(side: metrics.serviceGlyphSize),
            lineCap: .round,
            lineJoin: .round,
          ),
        )
        .accessibilityHidden(true)
    } else {
      CIRunGlyph(
        status: step.status,
        theme: theme,
        palette: theme.filesPanel,
        size: metrics.serviceGlyphSize,
      )
    }
  }

  @ViewBuilder private var heading: some View {
    let metrics = model.metrics
    let title = Text(path.title(of: step, base: base)).mergePathTitle(
      metrics: metrics,
      theme: theme,
    )
    if step.kind == .checks {
      Button {
        showsChecks.toggle()
      } label: {
        HStack(spacing: 6) {
          title
          DisclosureChevron(
            isExpanded: showsChecks,
            size: metrics.servicePageMarkSize,
            weight: .semibold,
            metrics: metrics,
          )
          .foregroundStyle(theme.filesPanel.textTertiary)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityValue(AccessibilityText.disclosure(isExpanded: showsChecks))
    } else {
      title
    }
  }

  private var railColor: Color {
    guard step.status == .passed else { return theme.filesPanel.border }
    return theme.color(for: CIRunStatus.passed, on: theme.filesPanel).opacity(
      Self.passedRailOpacity
    )
  }
}
