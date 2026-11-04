/// A Files panel page a worktree row's glyph opens, by the word `ui show`
/// spells it with.
public enum ServicePage: String, Codable, CaseIterable, Sendable {
  case ciRuns = "ci"
  case pullRequest = "pull-request"

  public var filesPanelMode: FilesPanelMode {
    switch self {
    case .ciRuns: .ciRuns
    case .pullRequest: .pullRequest
    }
  }
}
