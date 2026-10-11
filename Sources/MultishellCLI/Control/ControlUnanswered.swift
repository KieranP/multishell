import MultishellProcess

/// A request the app never answered, in the words the helper exits with.
enum ControlUnanswered: Error, CustomStringConvertible {
  /// It closed without a word, as an older app does.
  case silent
  case unreachable(SocketFailure)

  var description: String {
    switch self {
    case .silent: "Multishell gave no answer; it may be older than this helper"

    case .unreachable(let failure):
      "could not reach Multishell, is it running? `multishell open` starts it. \(failure)"
    }
  }
}
