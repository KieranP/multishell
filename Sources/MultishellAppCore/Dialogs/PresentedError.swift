import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// What the alert shows, built from the error types the app produces so
/// git's stderr is the message rather than a struct's description.
public struct PresentedError: Identifiable {
  public let id = UUID()
  public let title: String
  public let message: String
  /// Offered when the failure has a stronger form of the same action.
  public internal(set) var retry: Retry?
  /// Asked as a destructive choice beside Cancel, where any other is dismissed.
  var isRetryable: Bool { retry != nil }
  /// The launch alert about a missing git, which finding git on the login
  /// shell's PATH takes down; nothing else is dismissed by the model.
  private(set) var saysGitIsMissing = false

  init(title: String, message: String) {
    self.title = title
    self.message = message
  }

  init(_ error: any Error) {
    let alert =
      Self.hookOrFileListAlert(error) ?? Self.worktreeAlert(error) ?? Self.processAlert(error)
      ?? Self.settingsOrStateFileAlert(error)
      ?? (t("error.something-went-wrong"), Self.describe(error))
    title = alert.title
    message = alert.message
    saysGitIsMissing = error is GitUnavailable
  }

  typealias Alert = (title: String, message: String)

  /// What the cause said, a hook's startup noise cut away, then how it ended.
  /// Never the command line it ran as; a stop gives its reason instead.
  static func describe(_ error: any Error) -> String {
    // Each says it in English on itself, one from a target with no
    // catalogue to reach; see Docs/design/translation.md.
    if error is TrashTookNothing { return t("error.trash-took-nothing") }
    if error is TerminalUnavailable { return t("error.terminal-unavailable") }
    if let failure = error as? DescriptorUnavailable { return Self.descriptorMessage(failure) }
    if let failure = error as? ProcessFailure {
      let ending =
        switch failure.stop {
        case .none: t("error.exited-with-status", failure.status)
        case .timedOut(let after): t("hook.stopped-after-seconds", Self.seconds(after))
        case .byUser: t("error.stopped-by-you")
        }
      return failure.message.isEmpty
        ? t("error.printed-nothing", ending)
        : t("error.said-then-ending", failure.message, ending)
    }
    return String(describing: error)
  }

  private static func seconds(_ duration: Duration) -> Int {
    Int(duration.components.seconds)
  }
}
