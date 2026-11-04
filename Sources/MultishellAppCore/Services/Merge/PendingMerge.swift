import Foundation
import MultishellServices

/// The merge form of one worktree's pull request: what the host offered, and
/// what the user chose and wrote. Runtime only.
public struct PendingMerge: Equatable, Sendable {
  enum Phase: Equatable, Sendable {
    case editing
    case sending
    /// The host accepted it then; the form says so until the list shows it, or a
    /// list read begun after answers.
    case accepted(at: ContinuousClock.Instant)
    /// Done on one accepted: the page shows, but the banner offers nothing
    /// until the list says where it stands.
    case dismissed(acceptedAt: ContinuousClock.Instant)
  }

  /// What fills the form between its heading and its buttons.
  public enum Content: Equatable, Sendable {
    case reading
    /// The host's options could not be read; the model words why.
    case unread
    case methods([PullRequestMergeMethod], chosen: PullRequestMergeMethod)
  }

  /// One per opening, so a read an earlier opening began cannot fill it.
  let opening = UUID()
  let pullRequestNumber: Int
  /// Its page, naming its repository: another's pull request of the same number
  /// and head was never read for.
  let pullRequestURL: URL
  /// The head whose checks the page showed; the merge is held to it.
  let headCommit: String
  /// Follows the banner while editing, then stays what was sent.
  var waitsForChecks: Bool
  /// `nil` until the host answers.
  var options: PullRequestMergeOptions?
  var readFailure: ServiceReadFailure?
  /// Set with `options`, to the host's default.
  var method: PullRequestMergeMethod?
  /// Per method, so switching away and back keeps what was written.
  var edits: [PullRequestMergeMethod: PullRequestMergeMessage] = [:]
  var phase = Phase.editing

  public var isEditable: Bool { phase == .editing }
  public var isSending: Bool { phase == .sending }
  /// When the host accepted it, dismissed or not.
  var acceptedAt: ContinuousClock.Instant? {
    switch phase {
    case .accepted(let at), .dismissed(let at): at
    case .editing, .sending: nil
    }
  }

  var wasAccepted: Bool { acceptedAt != nil }
  var isDismissed: Bool { if case .dismissed = phase { true } else { false } }

  public var content: Content {
    if let options, let method { return .methods(options.methods, chosen: method) }
    return readFailure == nil ? .reading : .unread
  }

  /// `nil` for a method that takes none.
  public var message: PullRequestMergeMessage? {
    guard let method, method.takesMessage else { return nil }
    return edits[method] ?? options?.messages[method]
      ?? PullRequestMergeMessage(subject: "", body: "")
  }

  /// Restore Default shows only where the text differs from the host's.
  public var isEdited: Bool {
    guard let method, let edited = edits[method] else { return false }
    return edited != options?.messages[method]
  }

  /// What the host would refuse whatever was written.
  var refusal: MergeRefusal? {
    guard let options else { return nil }
    if !options.viewerMayMerge { return .viewerMayNotMerge }
    if waitsForChecks, !options.allowsAutoMerge { return .autoMergeOff }
    return nil
  }

  public var canConfirm: Bool { merge != nil }

  /// What confirming sends; `nil` while unread, refused or no longer editing,
  /// or with no subject.
  var merge: PullRequestMerge? {
    guard let method, refusal == nil, isEditable else { return nil }
    let message = message
    if let message, message.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return nil
    }
    return PullRequestMerge(
      method: method,
      message: message,
      headCommit: headCommit,
      waitsForChecks: waitsForChecks,
    )
  }

  init(of pullRequest: PullRequest, waitsForChecks: Bool) {
    pullRequestNumber = pullRequest.number
    pullRequestURL = pullRequest.url
    headCommit = pullRequest.headCommit
    self.waitsForChecks = waitsForChecks
  }
}
