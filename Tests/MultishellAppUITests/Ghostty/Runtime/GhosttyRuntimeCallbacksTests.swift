import Foundation
import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
@MainActor
struct GhosttyRuntimeCallbacksTests {
  private let ticker = GhosttyTicker()

  @Test func aClipboardReadOffTheMainThreadIsRefusedRatherThanStarted() async throws {
    let read = try #require(
      GhosttyRuntimeCallbacks.runtimeConfig(waking: ticker.userdata).read_clipboard_cb)
    // Never dereferenced: the thread is checked first.
    let view = UnsafeMutableRawPointer(bitPattern: 1)
    let result = await Task.detached {
      read(view, GHOSTTY_CLIPBOARD_STANDARD, nil, nil, 0, false)
    }.value
    #expect(result == GHOSTTY_CLIPBOARD_READ_UNAVAILABLE)
  }

  @Test func aClipboardReadWithNoSurfaceIsRefused() throws {
    let read = try #require(
      GhosttyRuntimeCallbacks.runtimeConfig(waking: ticker.userdata).read_clipboard_cb)
    #expect(
      read(nil, GHOSTTY_CLIPBOARD_STANDARD, nil, nil, 0, false)
        == GHOSTTY_CLIPBOARD_READ_UNAVAILABLE)
  }

  @Test func anActionForTheAppIsLeftToLibghostty() throws {
    let perform = try #require(
      GhosttyRuntimeCallbacks.runtimeConfig(waking: ticker.userdata).action_cb)
    var target = ghostty_target_s()
    target.tag = GHOSTTY_TARGET_APP
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_RING_BELL
    #expect(!perform(nil, target, action))
  }

  @Test func theRuntimeClaimsNoSelectionClipboard() {
    #expect(
      !GhosttyRuntimeCallbacks.runtimeConfig(waking: ticker.userdata).supports_selection_clipboard)
  }
}
