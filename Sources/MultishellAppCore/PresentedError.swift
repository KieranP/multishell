import Foundation
import MultishellCore
import MultishellGitKit
import MultishellProcess

/// What the alert shows. Built from the error types the app actually
/// produces, so git's stderr appears as the message rather than buried inside
/// a Swift description of a struct.
public struct PresentedError: Identifiable {
  public let id = UUID()
  public let title: String
  public let message: String
  /// Offered when the failure has a stronger form of the same action.
  public var retryLabel: String?
  public var retry: (@MainActor () async -> Void)?

  public init(title: String, message: String) {
    self.title = title
    self.message = message
  }

  public init(_ error: any Error) {
    switch error {
    case let failure as HookFailure:
      // A pre hook's failure stopped the operation; a post hook's came after
      // it succeeded. The title has to say which, and whether the hook
      // failed on its own or was ended from here.
      let ending =
        switch failure.stop {
        case .none: "failed"
        case .timedOut: "did not finish"
        case .stopped: "was stopped"
        }
      title =
        switch failure.stage {
        case .preCreate: "Worktree not created: its pre-create hook \(ending)"
        case .postCreate: "Worktree created, but its hook \(ending)"
        case .preDelete: "Worktree not removed: its pre-delete hook \(ending)"
        case .postDelete: "Worktree removed, but its hook \(ending)"
        }
      message = Self.describe(failure.underlying)
    case let failure as BranchDeletionFailure:
      title = "Worktree removed, but branch \(failure.branch) was not deleted"
      message = Self.describe(failure.underlying)
    case let failure as TrashFailure:
      title = "Worktree not removed: the directory could not be moved to the Trash or deleted"
      message = "\(failure.path.path)\n\n\(Self.describe(failure.underlying))"
    case let failure as ProcessFailure where failure.message.contains("invalid reference: HEAD"):
      // An unborn HEAD: the repository has never been committed to.
      title = "This repository has no commits yet"
      message = "A worktree needs a commit to start from. Make the first commit, then try again."
    case let failure as ProcessFailure:
      title = "\(failure.executable) \(failure.arguments.prefix(2).joined(separator: " ")) failed"
      message = failure.message.isEmpty ? "Exit status \(failure.status)." : failure.message
    case is GitUnavailable:
      title = "git not found"
      message = "Multishell runs git from your PATH and could not find it."
    case let failure as SocketFailure where failure.kind == .inUse:
      title = "Another Multishell is running"
      message =
        "It holds \(failure.path), so agent state reports go to it and this window's dots will not change. Quit one of them."
    case let failure as SocketFailure:
      title = "Session state reports are unavailable"
      message = "Could not listen on the socket: \(failure)"
    case let state as UnreadableState:
      title = "Saved state could not be read"
      message =
        "It was moved to \(state.backup.lastPathComponent) and Multishell started empty.\n\n\(state.underlying)"
    default:
      title = "Something went wrong"
      message = Self.describe(error)
    }
  }

  /// A hook's own words where it had any, its stdout and stderr with the
  /// shell's startup noise cut away, then the exit status on its own line:
  /// a hook that only echoes before it fails has nothing else to say about
  /// why. Never the command line it ran as. A hook ended from here gets the
  /// reason in place of the status, which is only the signal's.
  private static func describe(_ error: any Error) -> String {
    if let failure = error as? ProcessFailure {
      let ending =
        switch failure.stop {
        case .none: "Exited with status \(failure.status)"
        case .timedOut(let after): "Stopped after \(Self.seconds(after)), the hook timeout"
        case .stopped: "Stopped by you"
        }
      return failure.message.isEmpty
        ? "\(ending) and printed nothing." : "\(failure.message)\n\n\(ending)."
    }
    return String(describing: error)
  }

  private static func seconds(_ duration: Duration) -> String {
    let whole = duration.components.seconds
    return whole == 1 ? "1 second" : "\(whole) seconds"
  }
}
