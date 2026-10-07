import AppKit
import GhosttyKit

/// libghostty's clipboard reads, answered from the pasteboard.
extension GhosttySurfaceView {
  /// Answered before libghostty's callback returns, as Ghostty's own app does,
  /// so no read is left open.
  func answerClipboardRequest(
    _ request: GhosttyClipboardRequest, at location: ghostty_clipboard_e
  ) -> ghostty_clipboard_read_result_e {
    guard let surface else { return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE }
    let answer = GhosttyClipboardAnswer(request, at: location, text: PanePasteboard.pasteText())
    if case .reply(let text, let available) = answer {
      sendReply(to: request, text: text, available: available, confirmed: false, on: surface)
    }
    return answer.result
  }

  /// A paste Ghostty judges unsafe lands only once the user says so, in a sheet
  /// showing the text. One at a time; another meanwhile is refused.
  func confirmPaste(_ paste: GhosttyPasteConfirmation) {
    guard surface != nil, pendingPaste == nil, let window else {
      denyClipboardRequest(paste.request)
      return
    }
    let alert = UnsafePasteAlert.make(text: paste.text)
    pendingPaste = (paste, alert)
    alert.beginSheetModal(for: window) { [weak self] response in
      self?.answerPendingPaste(approved: response == .alertFirstButtonReturn)
    }
  }

  /// Also refused as the surface is freed, so no paste outlives it unanswered.
  func answerPendingPaste(approved: Bool) {
    guard let (paste, alert) = pendingPaste else { return }
    pendingPaste = nil
    alert.window.sheetParent?.endSheet(alert.window)
    guard let surface else { return }
    if approved {
      sendReply(to: paste.request, text: paste.text, available: [], confirmed: true, on: surface)
    } else {
      denyClipboardRequest(paste.request)
    }
  }

  /// A program's read, or a write it asks for, is refused unasked.
  func denyClipboardRequest(_ request: GhosttyClipboardRequest) {
    guard let surface else { return }
    ghostty_surface_deny_clipboard_request(surface, request.handle)
  }

  private func sendReply(
    to request: GhosttyClipboardRequest, text: String?, available: [String], confirmed: Bool,
    on surface: ghostty_surface_t
  ) {
    let strings = [GhosttyClipboardContents.textMime, text ?? ""] + available
    CStrings.with(strings) { strings in
      let contents =
        text == nil
        ? []
        : [
          ghostty_clipboard_content_s(mime: strings[0], data: strings[1], len: strlen(strings[1]))
        ]
      let available: [UnsafePointer<CChar>?] = Array(strings.dropFirst(2))
      contents.withUnsafeBufferPointer { contents in
        available.withUnsafeBufferPointer { available in
          var reply = ghostty_clipboard_complete_s(
            contents: contents.baseAddress, contents_len: contents.count,
            available: available.baseAddress, available_len: available.count,
            confirmed: confirmed, remember: false)
          ghostty_surface_complete_clipboard_request(surface, &reply, request.handle)
        }
      }
    }
  }
}
