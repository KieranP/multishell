import GhosttyKit

/// What a pane hands back for a clipboard read, from the pasteboard's text: the
/// text where the read takes it, and text named as on offer where it asked.
enum GhosttyClipboardAnswer: Equatable {
  case reply(text: String?, available: [String])
  case unavailable
  case unsupported

  var result: ghostty_clipboard_read_result_e {
    switch self {
    case .unsupported: GHOSTTY_CLIPBOARD_READ_UNSUPPORTED
    case .unavailable: GHOSTTY_CLIPBOARD_READ_UNAVAILABLE
    case .reply: GHOSTTY_CLIPBOARD_READ_STARTED
    }
  }

  /// Only the general pasteboard is the Mac's, and a read with nothing to
  /// hand back is unavailable, not refused.
  init(_ request: GhosttyClipboardRequest, at location: ghostty_clipboard_e, text: String?) {
    guard location == GHOSTTY_CLIPBOARD_STANDARD else {
      self = .unsupported
      return
    }
    let handedOver = request.wantsText ? text : nil
    guard handedOver != nil || request.wantsList else {
      self = .unavailable
      return
    }
    let available = request.wantsList && text != nil ? [GhosttyClipboardContents.textMime] : []
    self = .reply(text: handedOver, available: available)
  }
}
