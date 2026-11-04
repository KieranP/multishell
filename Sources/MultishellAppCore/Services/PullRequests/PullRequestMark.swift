import MultishellServices

/// How a pull request's glyph is drawn: its shape, the colour it takes, and
/// the dot on its corner; see Docs/design/services.md.
public struct PullRequestMark: Equatable, Sendable {
  public enum Shape: Equatable, Sendable {
    case closed
    case draft
    case merged
    case open
  }

  /// The pull request colours where the theme has them, else the greys of the
  /// area the glyph sits in.
  public enum Tone: Equatable, Sendable {
    case changesRequested
    case merged
    case primary
    case readyToMerge
    case secondary
    case tertiary
  }

  /// Only one is drawn: a conflict needs the user, auto-merge only waits.
  public enum Corner: Equatable, Sendable {
    case conflicts
    case queued
  }

  public let shape: Shape
  public let tone: Tone
  public let corner: Corner?

  public init(_ pullRequest: PullRequest) {
    switch pullRequest.state {
    case .closed:
      (shape, tone, corner) = (.closed, .secondary, nil)

    case .merged:
      (shape, tone, corner) = (.merged, .merged, nil)

    case .draft:
      (shape, tone, corner) = (.draft, .tertiary, Self.corner(of: pullRequest))

    case .open:
      (shape, tone, corner) = (.open, Self.openTone(of: pullRequest), Self.corner(of: pullRequest))
    }
  }

  /// Green only where the host would merge it now; an approval alone may
  /// still wait on its checks. Changes asked for stay red, required or not.
  private static func openTone(of pullRequest: PullRequest) -> Tone {
    switch pullRequest.review {
    case .changesRequested: .changesRequested
    case _ where pullRequest.isReadyToMerge: .readyToMerge
    case .approved, .notRequired: .primary
    case .required: .secondary
    }
  }

  private static func corner(of pullRequest: PullRequest) -> Corner? {
    if pullRequest.blocker == .conflicts { return .conflicts }
    return pullRequest.autoMergesWhenReady ? .queued : nil
  }
}
