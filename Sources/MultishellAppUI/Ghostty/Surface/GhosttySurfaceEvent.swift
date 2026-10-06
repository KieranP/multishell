import GhosttyKit

/// The surface actions the app answers, copied out of libghostty's payload,
/// whose pointers live only for the callback.
enum GhosttySurfaceEvent: Equatable {
  case retitled(String)
  case bell
  /// `nil` where the shell's integration reported no status.
  case commandFinished(exitCode: Int?)
  case pointerShape(ghostty_action_mouse_shape_e)
  case pointerVisible(Bool)
  /// libghostty saw a password prompt start or end, or a keybind toggled it.
  case secureInput(ghostty_action_secure_input_e)

  /// `nil` for an action this app leaves to libghostty or ignores.
  init?(_ action: ghostty_action_s) {
    switch action.tag {
    case GHOSTTY_ACTION_SET_TITLE:
      guard let title = action.action.set_title.title else { return nil }
      self = .retitled(String(cString: title))
    case GHOSTTY_ACTION_RING_BELL:
      self = .bell
    case GHOSTTY_ACTION_COMMAND_FINISHED:
      let code = action.action.command_finished.exit_code
      self = .commandFinished(exitCode: code < 0 ? nil : Int(code))
    case GHOSTTY_ACTION_MOUSE_SHAPE:
      self = .pointerShape(action.action.mouse_shape)
    case GHOSTTY_ACTION_SECURE_INPUT:
      self = .secureInput(action.action.secure_input)
    case GHOSTTY_ACTION_MOUSE_VISIBILITY:
      self = .pointerVisible(action.action.mouse_visibility == GHOSTTY_MOUSE_VISIBLE)
    default:
      return nil
    }
  }
}
