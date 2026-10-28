import Foundation
import MultishellCore
import MultishellServices

/// What the row's tooltip and the CI page say of a run.
extension CIRun {
  /// An earlier run's line: its commit's subject, else the commit itself.
  public var headline: String { subject ?? shortCommit }

  /// "CircleCI passed".
  public func statusText(provider: String) -> String {
    switch status {
    case .cancelled: t("ci.cancelled", provider)
    case .failed: t("ci.failed", provider)
    case .onHold: t("ci.on-hold", provider)
    case .passed: t("ci.passed", provider)
    case .running: t("ci.running", provider)
    }
  }

  /// "Started 4 minutes ago · the local tip", saying nothing of a tip unknown.
  public func startText(localTip: String?) -> String {
    let tip = localTip.map { ran($0) ? t("ci.the-local-tip") : t("ci.not-the-local-tip") }
    let started = createdAt.map { t("ci.started", $0.formatted(.relative(presentation: .named))) }
    switch (started, tip) {
    case (let started?, let tip?): return t("ci.when-on-tip", started, tip)
    case (let started?, nil): return started
    case (nil, let tip?): return tip
    case (nil, nil): return ""
    }
  }
}
