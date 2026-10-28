import Foundation

/// How often the services are asked; see Docs/design/services.md.
enum ServiceReadInterval {
  /// What anything happening on the host waits at most to be seen: a review,
  /// a teammate's push, a run starting.
  static let poll: Duration = .seconds(120)
  /// A run under way is asked about this often, its end being the news.
  static let underWay: Duration = .seconds(60)
  /// A return to the front asks again only past this, so switching apps
  /// back and forth asks nothing.
  static let activation: Duration = .seconds(30)
  /// How long "not ours" stands with the remotes unchanged: an Enterprise
  /// host is not ours until `gh auth login` names it.
  private static let notHostedRecheck: TimeInterval = 600

  /// Whether a "not ours" first given at `since`, and given again each time
  /// since, still answers without asking.
  static func notHostedStands(since: Date?) -> Bool {
    since.map { Date.now.timeIntervalSince($0) < notHostedRecheck } ?? false
  }
}
