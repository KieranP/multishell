import GhosttyKit
import MultishellCore

extension ProgramStatus {
  /// Copied out of libghostty's payload, whose strings live only for the
  /// callback. `nil` for a state a later libghostty adds.
  init?(_ action: ghostty_action_program_status_s) {
    guard let state = Self.state(action.state) else { return nil }
    self.init(
      state: state,
      blockedReason: Self.blockedReason(action.kind),
      recordID: action.id.map { String(cString: $0) },
      app: action.app.map { String(cString: $0) },
      message: action.msg.map { String(cString: $0) },
    )
  }

  private static func state(_ state: ghostty_action_program_status_state_e) -> State? {
    switch state {
    case GHOSTTY_PROGRAM_STATUS_IDLE: .idle
    case GHOSTTY_PROGRAM_STATUS_WORKING: .working
    case GHOSTTY_PROGRAM_STATUS_DONE: .done
    case GHOSTTY_PROGRAM_STATUS_BLOCKED: .blocked
    case GHOSTTY_PROGRAM_STATUS_ERROR: .failed
    case GHOSTTY_PROGRAM_STATUS_CLEAR: .clear
    default: nil
    }
  }

  private static func blockedReason(
    _ kind: ghostty_action_program_status_kind_e
  ) -> BlockedReason? {
    switch kind {
    case GHOSTTY_PROGRAM_STATUS_KIND_PERMISSION: .permission
    case GHOSTTY_PROGRAM_STATUS_KIND_QUESTION: .question
    case GHOSTTY_PROGRAM_STATUS_KIND_AUTH: .auth
    default: nil
    }
  }
}
