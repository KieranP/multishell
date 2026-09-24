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
  public var retry: Retry?
  /// The launch alert about a missing git, which finding git on the login
  /// shell's PATH takes down; nothing else is dismissed by the model.
  private(set) var saysGitIsMissing = false

  public init(title: String, message: String) {
    self.title = title
    self.message = message
  }

  public init(_ error: any Error) {
    switch error {
    case let failure as HookFailure:
      // A pre hook's failure stopped the operation, a post hook's came
      // after it. The title says which, and who ended the hook.
      let ending =
        switch failure.stop {
        case .none: t("error.hook-failed")
        case .timedOut: t("error.hook-did-not-finish")
        case .stopped: t("error.hook-was-stopped")
        }
      title =
        switch failure.stage {
        case .preCreate: t("error.pre-create-hook", ending)
        case .postCreate: t("error.post-create-hook", ending)
        case .preDelete: t("error.pre-delete-hook", ending)
        case .postDelete: t("error.post-delete-hook", ending)
        }
      message = Self.describe(failure.underlying)
    case let failure as WorktreeFileFailure:
      title =
        switch failure.placement {
        case .link: t("error.files-not-linked")
        case .copy: t("error.files-not-copied")
        }
      message = ([failure.description] + Self.describeSkipped(failure.skippedEntries))
        .joined(separator: "\n\n")
    case let failure as BranchDeletionFailure:
      title = t("error.branch-not-deleted", failure.branch)
      message = Self.describe(failure.underlying)
    case let failure as TrashFailure:
      title = t("error.trash-refused")
      message = "\(failure.path.path)\n\n\(Self.describe(failure.underlying))"
    case let failure as WorktreeForgetFailure:
      title = t("error.forget-refused")
      message = "\(failure.path.path)\n\n\(Self.describe(failure.underlying))"
    case let skipped as WorktreeFilesSkipped:
      title = t("error.files-skipped-title")
      message = Self.describeSkipped(skipped.entries).joined()
    case let failure as NotTheCheckout:
      title = t("error.not-the-checkout-title")
      message = t("error.not-the-checkout-message", failure.path.path)
    case let failure as ProcessFailure where failure.message.contains("invalid reference: HEAD"):
      // An unborn HEAD: the repository has never been committed to.
      title = t("error.no-commits-title")
      message = t("error.no-commits-message")
    case let failure as ProcessFailure where failure.arguments.first == "fetch":
      // Fetch runs with no terminal to answer on, so a repository wanting a
      // password waits out the timeout: the likeliest way this ends.
      switch failure.stop {
      case .timedOut:
        title = t("error.fetch-timed-out-title")
        message = t("error.fetch-timed-out-message")
      case .stopped, .none:
        title = t("error.fetch-failed-title")
        message =
          failure.message.isEmpty
          ? t("error.exit-status", failure.status) : failure.message
      }
    case let failure as ProcessFailure:
      title = t(
        "error.command-failed-title",
        failure.executable, failure.arguments.prefix(2).joined(separator: " "))
      message =
        failure.message.isEmpty ? t("error.exit-status", failure.status) : failure.message
    case let invalid as InvalidBranchName:
      title = t("error.invalid-branch-title")
      message = invalid.errorDescription ?? ""
    case let repository as NotAWorktree:
      title = t("error.not-a-worktree-title")
      message = repository.errorDescription ?? ""
    case is GitUnavailable:
      title = t("error.git-not-found-title")
      message = t("error.git-not-found-message")
      saysGitIsMissing = true
    case let failure as SocketFailure:
      (title, message) = Self.socketAlert(failure)
    case let failure as PipeUnavailable:
      title = t("error.no-pipe-title")
      message = Self.pipeMessage(failure)
    case let entries as UnreadableHookEntries:
      title = t("error.unknown-hooks-title")
      message = t("error.unknown-hooks-message", entries.file.path, entries.event)
    case let section as UnreadableHookSection:
      title = t("error.unknown-hooks-title")
      message = t("error.unknown-hooks-section-message", section.file.path)
    case let unparsable as UnparsableSettingsFile:
      title = t("error.unparsable-settings-title")
      message = t("error.unparsable-settings-message", unparsable.file.path)
    case let shape as UnexpectedSettingsShape:
      title = t("error.settings-shape-title")
      message = t("error.settings-shape-message", shape.file.path)
    case let state as UnreadableState:
      title = t("error.unreadable-state-title")
      message = t(
        "error.unreadable-state-message",
        state.backup.lastPathComponent, String(describing: state.underlying))
    case let state as UnmovedState:
      title = t("error.unreadable-state-title")
      message = t(
        "error.unmoved-state-message",
        state.file.path, String(describing: state.underlying))
    default:
      title = t("error.something-went-wrong")
      message = Self.describe(error)
    }
  }

  /// What an entry must be, and the entries that were not; none for none.
  private static func describeSkipped(_ entries: [String]) -> [String] {
    guard !entries.isEmpty else { return [] }
    return [t("error.files-skipped-message", entries.map { "• " + $0 }.joined(separator: "\n"))]
  }

  /// A hook's own words, startup noise cut away, then its exit status.
  /// Never the command line it ran as; a stop gives its reason instead.
  private static func describe(_ error: any Error) -> String {
    // Each says it in English on itself, two from a target with no
    // catalogue to reach; see Docs/design/translation.md.
    if error is ShellUnavailable { return t("error.no-shell") }
    if error is TrashTookNothing { return t("error.trash-took-nothing") }
    if let failure = error as? PipeUnavailable { return Self.pipeMessage(failure) }
    if let failure = error as? ProcessFailure {
      let ending =
        switch failure.stop {
        case .none: t("error.exited-with-status", failure.status)
        case .timedOut(let after): t("hook.stopped-after-seconds", Self.seconds(after))
        case .stopped: t("error.stopped-by-you")
        }
      return failure.message.isEmpty
        ? t("error.printed-nothing", ending)
        : t("error.said-then-ending", failure.message, ending)
    }
    return String(describing: error)
  }

  private static func pipeMessage(_ failure: PipeUnavailable) -> String {
    t("error.no-pipe-message", String(cString: strerror(failure.code)), failure.code)
  }

  /// A second copy holding the socket is its own alert; the rest say what
  /// the call was. Only `strerror` stays in English, being the system's.
  private static func socketAlert(_ failure: SocketFailure) -> (title: String, message: String) {
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

extension PresentedError {
  /// The stronger form and the button naming it, one value so neither can be
  /// set without the other.
  public struct Retry {
    public let label: String
    public let action: @MainActor () async -> Void

    init(label: String, action: @escaping @MainActor () async -> Void) {
      self.label = label
      self.action = action
    }
  }
}
