import GhosttyKit
import MultishellCore

/// The surface actions the app answers, copied out of libghostty's payload,
/// whose pointers live only for the callback.
enum GhosttySurfaceEvent: Equatable {
  case bell
  /// `nil` where the shell's integration reported no status.
  case commandFinished(exitCode: Int?)
  /// `nil` where the shell said it no longer knows.
  case directoryReported(String?)
  /// An OSC 8 link, whose target the pane never shows.
  case hyperlinkClicked(String)
  /// A link clicked in the pane's text.
  case linkClicked(String)
  case pointerShape(ghostty_action_mouse_shape_e)
  case pointerVisible(Bool)
  case retitled(String)
  case searchCount(TerminalSearchCount)
  /// libghostty saw a password prompt start or end, or a keybind toggled it.
  case secureInput(ghostty_action_secure_input_e)

  /// Answered even when its view has gone. Declined, a pane's link reaches
  /// libghostty's `open`, which logs a warning and refuses it.
  var isLinkClick: Bool {
    switch self {
    case .hyperlinkClicked, .linkClicked: true
    default: false
    }
  }

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

    case GHOSTTY_ACTION_OPEN_URL:
      let link = action.action.open_url
      // Ghostty's own text and HTML files stay libghostty's. A kind it adds
      // later is judged here rather than left to libghostty.
      guard
        link.kind != GHOSTTY_ACTION_OPEN_URL_KIND_TEXT,
        link.kind != GHOSTTY_ACTION_OPEN_URL_KIND_HTML,
        let url = link.url
      else { return nil }
      let target = String(
        decoding: UnsafeRawBufferPointer(start: url, count: Int(link.len)),
        as: UTF8.self,
      )
      self =
        link.kind == GHOSTTY_ACTION_OPEN_URL_KIND_OSC8
        ? .hyperlinkClicked(target) : .linkClicked(target)

    case GHOSTTY_ACTION_PWD:
      guard let pwd = action.action.pwd.pwd else { return nil }
      let path = String(cString: pwd)
      self = .directoryReported(path.isEmpty ? nil : path)

    case GHOSTTY_ACTION_MOUSE_SHAPE:
      self = .pointerShape(action.action.mouse_shape)

    case GHOSTTY_ACTION_SECURE_INPUT:
      self = .secureInput(action.action.secure_input)

    case GHOSTTY_ACTION_SEARCH_TOTAL:
      let total = action.action.search_total.total
      self = .searchCount(.total(total < 0 ? nil : total))

    case GHOSTTY_ACTION_SEARCH_SELECTED:
      let selected = action.action.search_selected.selected
      self = .searchCount(.selected(selected < 0 ? nil : selected))

    case GHOSTTY_ACTION_MOUSE_VISIBILITY:
      self = .pointerVisible(action.action.mouse_visibility == GHOSTTY_MOUSE_VISIBLE)

    default:
      return nil
    }
  }
}
