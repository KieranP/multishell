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

  private typealias Alert = (title: String, message: String)

  /// A hook, or a file list, around a create or a removal.
  private static func hookOrFileListAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as HookFailure:
      // A pre hook's failure stopped the operation, a post hook's came
      // after it. The title says which, and who ended the hook.
      let ending =
        switch failure.stop {
        case .none: t("error.hook-failed")
        case .timedOut: t("error.hook-did-not-finish")
        case .byUser: t("error.hook-was-stopped")
        }
      let title =
        switch failure.stage {
        case .preCreate: t("error.pre-create-hook", ending)
        case .postCreate: t("error.post-create-hook", ending)
        case .preDelete: t("error.pre-delete-hook", ending)
        case .postDelete: t("error.post-delete-hook", ending)
        }
      return (title, describe(failure.underlying))
    case let failure as WorktreeFileFailure:
      let title =
        switch failure.placement {
        case .link: t("error.files-not-linked")
        case .copy: t("error.files-not-copied")
        }
      return (
        title, ([failure.description] + describeSkipped(failure.skipped)).joined(separator: "\n\n")
      )
    case let skipped as WorktreeFileSkipped:
      return (t("error.files-skipped-title"), describeSkipped(skipped.entries).joined())
    default:
      return nil
    }
  }

  /// What git or the Trash refused about a worktree or a branch.
  private static func worktreeAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as BranchDeletionFailure:
      return (t("error.branch-not-deleted", failure.branch), describe(failure.underlying))
    case let failure as TrashFailure:
      return (t("error.trash-refused"), pathAndCause(failure.path, failure.underlying))
    case let failure as WorktreeForgetFailure:
      return (t("error.forget-refused"), pathAndCause(failure.path, failure.underlying))
    case let failure as NotTheCheckout:
      return (
        t("error.not-the-checkout-title"), t("error.not-the-checkout-message", failure.path.path)
      )
    case let invalid as InvalidBranchName:
      return (t("error.invalid-branch-title"), invalid.errorDescription ?? "")
    case let repository as WorktreeNotRemovable:
      return (t("error.not-a-worktree-title"), repository.errorDescription ?? "")
    case is GitUnavailable:
      return (t("error.git-not-found-title"), t("error.git-not-found-message"))
    default:
      return nil
    }
  }

  /// A child process, a file descriptor or the socket.
  private static func processAlert(_ error: any Error) -> Alert? {
    switch error {
    case let failure as ProcessFailure where failure.message.contains("invalid reference: HEAD"):
      // An unborn HEAD: the repository has never been committed to.
      return (t("error.no-commits-title"), t("error.no-commits-message"))
    case let failure as ProcessFailure where failure.arguments.first == "fetch":
      // Fetch runs with no terminal to answer on, so a repository wanting a
      // password waits out the timeout: the likeliest way this ends.
      switch failure.stop {
      case .timedOut:
        return (t("error.fetch-timed-out-title"), t("error.fetch-timed-out-message"))
      case .byUser, .none:
        return (t("error.fetch-failed-title"), outputOrStatus(failure))
      }
    case let failure as ProcessFailure:
      return (
        t(
          "error.command-failed-title",
          failure.executable, failure.arguments.prefix(2).joined(separator: " ")),
        outputOrStatus(failure)
      )
    case let failure as SocketFailure:
      return socketAlert(failure)
    case let failure as DescriptorUnavailable:
      return (t("error.no-descriptor-title"), descriptorMessage(failure))
    default:
      return nil
    }
  }

  /// An agent's settings file, or the app's own state file, that would not read.
  private static func settingsOrStateFileAlert(_ error: any Error) -> Alert? {
    switch error {
    case let entries as UnreadableHookEntries:
      return (
        t("error.unknown-hooks-title"),
        t("error.unknown-hooks-message", entries.file.path, entries.event)
      )
    case let section as UnreadableHookSection:
      return (
        t("error.unknown-hooks-title"),
        t("error.unknown-hooks-section-message", section.file.path)
      )
    case let unparsable as UnparsableSettingsFile:
      return (
        t("error.unparsable-settings-title"),
        t("error.unparsable-settings-message", unparsable.file.path)
      )
    case let shape as UnexpectedSettingsShape:
      return (t("error.settings-shape-title"), t("error.settings-shape-message", shape.file.path))
    case let state as UnreadableStateFile:
      return (
        t("error.unreadable-state-title"),
        t(
          "error.unreadable-state-message",
          state.backup.lastPathComponent, String(describing: state.underlying))
      )
    case let state as UnmovableStateFile:
      return (
        t("error.unreadable-state-title"),
        t("error.unmoved-state-message", state.file.path, String(describing: state.underlying))
      )
    default:
      return nil
    }
  }

  /// What an entry must be, and the entries that were not; none for none.
  private static func describeSkipped(_ entries: [String]) -> [String] {
    guard !entries.isEmpty else { return [] }
    return [t("error.files-skipped-message", entries.map { "• " + $0 }.joined(separator: "\n"))]
  }

  /// What the cause said, a hook's startup noise cut away, then how it ended.
  /// Never the command line it ran as; a stop gives its reason instead.
  private static func describe(_ error: any Error) -> String {
    // Each says it in English on itself, one from a target with no
    // catalogue to reach; see Docs/design/translation.md.
    if error is TrashTookNothing { return t("error.trash-took-nothing") }
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

  private static func pathAndCause(_ path: URL, _ underlying: any Error) -> String {
    "\(path.path)\n\n\(describe(underlying))"
  }

  private static func outputOrStatus(_ failure: ProcessFailure) -> String {
    failure.message.isEmpty ? t("error.exit-status", failure.status) : failure.message
  }

  private static func descriptorMessage(_ failure: DescriptorUnavailable) -> String {
    t("error.no-descriptor-message", String(cString: strerror(failure.code)), failure.code)
  }

  /// A second copy holding the socket is its own alert; the rest say what
  /// the call was. Only `strerror` stays in English, being the system's.
  private static func socketAlert(_ failure: SocketFailure) -> Alert {
    switch failure.kind {
    case .inUse:
      (t("error.another-app-title"), t("error.another-app-message", failure.path))
    case .pathTooLong:
      (
        t("error.socket-title"),
        t("error.socket-message", t("error.socket-path-too-long", failure.path))
      )
    case .system(let operation, let code):
      (
        t("error.socket-title"),
        t(
          "error.socket-message",
          t(
            "error.socket-call-failed", operation, failure.path,
            String(cString: strerror(code)), code))
      )
    }
  }

  private static func seconds(_ duration: Duration) -> Int {
    Int(duration.components.seconds)
  }
}
