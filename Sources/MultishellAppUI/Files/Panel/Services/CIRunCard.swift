import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The newest run's outcome, the commit it ran and when, and the corner glyph
/// that opens the branch's runs on the provider.
struct CIRunCard: View {
  let model: AppModel
  let worktree: Worktree
  let run: CIRun
  let theme: Theme

  var body: some View {
    let metrics = model.metrics
    let services = model.services(of: worktree)
    let provider = model.ciProviderName(of: worktree) ?? ""
    PanelCard(theme: theme) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: UIMetrics.serviceCardGlyphSpacing) {
          CIRunGlyph(
            status: run.status,
            theme: theme,
            palette: theme.header,
            size: metrics.serviceGlyphSize,
          )
          Text(run.statusText(provider: provider))
            .font(metrics.font(size: metrics.secondary, weight: .semibold))
            .foregroundStyle(theme.header.text)
        }
        .padding(.trailing, ExternalLinkButton.clearance(forSize: metrics.glyph))
        Group {
          HStack(spacing: 6) {
            Text(run.shortCommit)
              .font(.system(size: metrics.caption, design: .monospaced))
            if let subject = run.subject {
              Text(subject).font(metrics.font(size: metrics.caption))
            }
          }
          .foregroundStyle(theme.header.textSecondary)
          .lineLimit(1)
          Text(run.startText(localTip: services.localTip))
            .font(metrics.font(size: metrics.caption))
            .foregroundStyle(theme.header.textTertiary)
        }
        .padding(.leading, metrics.serviceCardTextIndent)
      }
      .cornerLink(
        help: t("action.open-on", provider),
        size: metrics.glyph,
        color: theme.header.textSecondary,
      ) {
        Task { await model.openCIRuns(of: worktree) }
      }
    }
  }
}
