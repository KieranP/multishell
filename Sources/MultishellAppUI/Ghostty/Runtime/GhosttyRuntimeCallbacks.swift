import AppKit
import GhosttyKit

/// The C callbacks libghostty calls into. Each reaches a surface's view, its userdata,
/// but the wakeup, which reaches the ticker, and a copy, which goes to the pasteboard.
enum GhosttyRuntimeCallbacks {
  /// `ticker` is a `GhosttyTicker`'s userdata, the one thing a wakeup reaches.
  static func runtimeConfig(waking ticker: UnsafeMutableRawPointer) -> ghostty_runtime_config_s {
    // The Mac has no selection clipboard; Ghostty's own app keeps a private
    // one, which nothing outside a pane could read.
    let supportsSelectionClipboard = false
    return ghostty_runtime_config_s(
      userdata: ticker,
      supports_selection_clipboard: supportsSelectionClipboard,
      wakeup_cb: { GhosttyTicker.wakeUp($0) },
      action_cb: { _, target, action in GhosttyRuntimeCallbacks.perform(action, on: target) },
      read_clipboard_cb: { userdata, location, request, mimes, count, wantsList in
        GhosttyRuntimeCallbacks.readClipboard(userdata, location, request, mimes, count, wantsList)
      },
      confirm_read_clipboard_cb: { userdata, confirm, handle, kind in
        GhosttyRuntimeCallbacks.confirmReadClipboard(userdata, confirm, handle, kind)
      },
      write_clipboard_cb: { _, location, contents, count, needsConfirming in
        guard
          let text = GhosttyClipboardContents.textToWrite(
            UnsafeBufferPointer(start: contents, count: count), at: location,
            needsConfirming: needsConfirming)
        else { return }
        DispatchQueue.main.async { NSPasteboard.general.replaceContents(withText: text) }
      },
      close_surface_cb: { userdata, _ in
        GhosttyRuntimeCallbacks.withView(userdata) { $0.surfaceDidClose() }
      }
    )
  }

  /// Surface actions decoded on the thread they arrive on, the payload's
  /// pointers living only that long; `false` lets libghostty act itself.
  private static func perform(_ action: ghostty_action_s, on target: ghostty_target_s) -> Bool {
    guard target.tag == GHOSTTY_TARGET_SURFACE,
      let event = GhosttySurfaceEvent(action),
      let userdata = ghostty_surface_userdata(target.target.surface)
    else { return false }
    withView(userdata) { $0.receive(event) }
    return true
  }

  /// Text only, the one representation a pane pastes. libghostty reads from
  /// its tick on the main thread; anywhere else no read is started to hang.
  private static func readClipboard(
    _ userdata: UnsafeMutableRawPointer?, _ location: ghostty_clipboard_e,
    _ handle: UnsafeMutableRawPointer?, _ mimes: UnsafePointer<UnsafePointer<CChar>?>?,
    _ count: Int, _ wantsList: Bool
  ) -> ghostty_clipboard_read_result_e {
    guard let userdata, Thread.isMainThread else { return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE }
    let asked = UnsafeBufferPointer(start: mimes, count: mimes == nil ? 0 : count)
    let request = GhosttyClipboardRequest(
      handle: handle,
      wantsText: asked.contains {
        $0.map(String.init(cString:)) == GhosttyClipboardContents.textMime
      },
      wantsList: wantsList)
    let view = view(from: userdata)
    return MainActor.assumeIsolated { view.answerClipboardRequest(request, at: location) }
  }

  /// The paste libghostty wants confirmed, its contents copied out before
  /// the callback returns; one that cannot be read is denied.
  private static func confirmReadClipboard(
    _ userdata: UnsafeMutableRawPointer?, _ confirm: UnsafePointer<ghostty_clipboard_confirm_s>?,
    _ handle: UnsafeMutableRawPointer?, _ kind: ghostty_clipboard_request_e
  ) {
    let request = GhosttyClipboardRequest(handle: handle)
    let paste = confirm.flatMap {
      let contents = $0.pointee.contents
      return GhosttyPasteConfirmation(
        request, kind: kind,
        contents: UnsafeBufferPointer(
          start: contents, count: contents == nil ? 0 : $0.pointee.contents_len))
    }
    withView(userdata) { view in
      if let paste { view.confirmPaste(paste) } else { view.denyClipboardRequest(request) }
    }
  }

  /// Inline where libghostty already is on the main thread, as it is inside a
  /// tick; a turn later otherwise, the view kept alive until the block runs.
  private static func withView(
    _ userdata: UnsafeMutableRawPointer?,
    _ body: @escaping @MainActor (GhosttySurfaceView) -> Void
  ) {
    guard let userdata else { return }
    let view = view(from: userdata)
    if Thread.isMainThread {
      MainActor.assumeIsolated { body(view) }
    } else {
      DispatchQueue.main.async { body(view) }
    }
  }

  private static func view(from userdata: UnsafeMutableRawPointer) -> GhosttySurfaceView {
    Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
  }
}
