import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// The pull request and CI glyphs' colours: the theme's `ui.pull_requests`
/// and `ui.ci` where it has one, the greys of the area they sit on otherwise.
extension Theme {
  func color(for tone: PullRequestMark.Tone, on palette: AreaPalette) -> Color {
    switch tone {
    case .changesRequested: color(.changesRequested, in: .pullRequests)
    case .merged: mergedColor
    case .primary: palette.text
    case .readyToMerge: color(.readyToMerge, in: .pullRequests)
    case .secondary: palette.textSecondary
    case .tertiary: palette.textTertiary
    }
  }

  func color(for corner: PullRequestMark.Corner) -> Color {
    switch corner {
    case .conflicts: color(.conflicts, in: .pullRequests)
    case .queued: color(.queued, in: .pullRequests)
    }
  }

  func color(for status: CIRunStatus, on palette: AreaPalette) -> Color {
    switch status {
    case .cancelled: palette.textSecondary
    case .failed: color(.failed, in: .ciRuns)
    case .onHold: color(.onHold, in: .ciRuns)
    case .passed: color(.passed, in: .ciRuns)
    case .running: color(.running, in: .ciRuns)
    }
  }
}
