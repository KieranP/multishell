import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// One merge path step: its glyph on the rail, title and hint, its checks or
/// threads, and its own checkbox where it has something to send.
struct MergePathStepRow: View {
  private static let railWidth = 1.5
  /// Between the glyph and the rail under it.
  private static let railGap = 3.0
  /// Under each step, the rail running on through it.
  private static let stepSpacing = 14.0
  /// The rail under a passed step, faded so the glyphs on it stay first.
  private static let passedRailOpacity = 0.55

  let model: AppModel
  let worktree: Worktree
  let pullRequest: PullRequest
  let path: MergePath
  let step: MergePath.Step
  /// The pull request's unresolved threads, read once for every step.
  let threads: [PullRequestThread]
  let base: String
  let host: String
  let theme: Theme
  @Binding var showsChecks: Bool
  @Binding var showsThreads: Bool

  var body: some View {
    let metrics = model.metrics
    let items = model.mergePathStepItems(of: step, in: path, on: pullRequest, threads: threads)
    let isExpanded = isExpanded(items)
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
        HStack(alignment: .top, spacing: 8) {
          MergePathWords(
            hint: hint(items, isCollapsed: isExpanded?.wrappedValue == false),
            metrics: metrics,
            theme: theme,
          ) {
            heading(isExpanded)
          }
          Spacer(minLength: 0)
          if let state = model.handoffGroupState(of: items.candidates, in: worktree.id) {
            HandoffCheckbox(state: state, label: items.sendAllLabel) {
              model.toggleHandoffGroup(items.candidates, in: worktree.id)
            }
            .frame(width: metrics.handoffSlotWidth, alignment: .trailing)
          }
        }
        if step.kind == .checks, showsChecks, let checks = path.checks {
          VStack(spacing: 0) {
            ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
              PullRequestCheckRow(
                model: model,
                check: check,
                worktreeID: worktree.id,
                showsHandoffSlot: items.showsHandoffSlot,
                candidate: items.checkCandidates[check],
                theme: theme,
              )
            }
          }
          .padding(.top, 7)
        }
        if !items.threads.isEmpty, showsThreads {
          VStack(spacing: 0) {
            ForEach(items.threads, id: \.id) { thread in
              if let candidate = items.candidate(of: thread) {
                PullRequestThreadRow(
                  model: model,
                  thread: thread,
                  candidate: candidate,
                  worktreeID: worktree.id,
                  theme: theme,
                )
              }
            }
          }
          .padding(.top, 5)
        }
      }
      .padding(.bottom, Self.stepSpacing)
    }
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, UIMetrics.servicePageSideInset)
  }

  private var stepTitle: String { path.title(of: step, base: base) }

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
    } else if step.kind == .comments {
      SpeechBubbleShape()
        .stroke(
          theme.filesPanel.textSecondary,
          style: StrokeStyle(
            lineWidth: UIMetrics.statusGlyphLineWidth(side: metrics.serviceGlyphSize),
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

  private var railColor: Color {
    guard step.status == .passed else { return theme.filesPanel.border }
    return theme.color(for: CIRunStatus.passed, on: theme.filesPanel).opacity(
      Self.passedRailOpacity
    )
  }

  /// Whether the step's list shows; `nil` where it has none.
  private func isExpanded(_ items: MergePathStepItems) -> Binding<Bool>? {
    switch items.collapsibleList {
    case .checks: $showsChecks
    case .threads: $showsThreads
    case nil: nil
    }
  }

  private func hint(_ items: MergePathStepItems, isCollapsed: Bool) -> String? {
    model.mergePathHint(
      of: step,
      in: path,
      base: base,
      host: host,
      items: items,
      isCollapsed: isCollapsed,
      in: worktree.id,
    )
  }

  @ViewBuilder private func heading(_ isExpanded: Binding<Bool>?) -> some View {
    let metrics = model.metrics
    let title = Text(stepTitle).mergePathTitle(metrics: metrics, theme: theme)
    if let isExpanded {
      Button {
        isExpanded.wrappedValue.toggle()
      } label: {
        HStack(spacing: 6) {
          title
          DisclosureChevron(
            isExpanded: isExpanded.wrappedValue,
            size: metrics.servicePageMarkSize,
            weight: .semibold,
            metrics: metrics,
          )
          .foregroundStyle(theme.filesPanel.textTertiary)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityValue(AccessibilityText.disclosure(isExpanded: isExpanded.wrappedValue))
    } else {
      title
    }
  }
}
