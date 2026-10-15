import GhosttyKit
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttySurfaceEventTests {
  private func action(
    _ tag: ghostty_action_tag_e,
    _ payload: ghostty_action_u = .init(),
  )
    -> ghostty_action_s
  {
    ghostty_action_s(tag: tag, action: payload)
  }

  @Test func aTitleIsCopiedOutOfThePayload() {
    let event = "~/code".withCString { title in
      var payload = ghostty_action_u()
      payload.set_title = ghostty_action_set_title_s(title: title)
      return GhosttySurfaceEvent(action(GHOSTTY_ACTION_SET_TITLE, payload))
    }
    #expect(event == .retitled("~/code"))
  }

  @Test func aCommandsStatusIsKeptAndAMissingOneIsNil() {
    var payload = ghostty_action_u()
    payload.command_finished = ghostty_action_command_finished_s(exit_code: 2, duration: 0)
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_COMMAND_FINISHED, payload))
        == .commandFinished(exitCode: 2)
    )
    payload.command_finished.exit_code = -1
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_COMMAND_FINISHED, payload))
        == .commandFinished(exitCode: nil)
    )
  }

  @Test func aPointerShapeAProgramAsksForIsKept() {
    var payload = ghostty_action_u()
    payload.mouse_shape = GHOSTTY_MOUSE_SHAPE_TEXT
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_MOUSE_SHAPE, payload))
        == .pointerShape(GHOSTTY_MOUSE_SHAPE_TEXT)
    )
  }

  @Test func hidingAndShowingThePointerAreEvents() {
    var payload = ghostty_action_u()
    payload.mouse_visibility = GHOSTTY_MOUSE_HIDDEN
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_MOUSE_VISIBILITY, payload))
        == .pointerVisible(false)
    )
    payload.mouse_visibility = GHOSTTY_MOUSE_VISIBLE
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_MOUSE_VISIBILITY, payload))
        == .pointerVisible(true)
    )
  }

  @Test func aTitleWithNoTextIsNoEvent() {
    var payload = ghostty_action_u()
    payload.set_title = ghostty_action_set_title_s(title: nil)
    #expect(GhosttySurfaceEvent(action(GHOSTTY_ACTION_SET_TITLE, payload)) == nil)
  }

  @Test func aPasswordPromptAsksForSecureInput() {
    var payload = ghostty_action_u()
    payload.secure_input = GHOSTTY_SECURE_INPUT_ON
    #expect(
      GhosttySurfaceEvent(action(GHOSTTY_ACTION_SECURE_INPUT, payload))
        == .secureInput(GHOSTTY_SECURE_INPUT_ON)
    )
  }

  @Test func aRungBellIsTheBellEvent() {
    #expect(GhosttySurfaceEvent(action(GHOSTTY_ACTION_RING_BELL)) == .bell)
  }

  @Test func anActionTheAppLeavesToLibghosttyIsNoEvent() {
    #expect(GhosttySurfaceEvent(action(GHOSTTY_ACTION_NEW_WINDOW)) == nil)
  }

  private func openURLEvent(
    _ text: String,
    kind: ghostty_action_open_url_kind_e,
  ) -> GhosttySurfaceEvent? {
    text.withCString { url in
      var payload = ghostty_action_u()
      payload.open_url = ghostty_action_open_url_s(kind: kind, url: url, len: UInt(strlen(url)))
      return GhosttySurfaceEvent(action(GHOSTTY_ACTION_OPEN_URL, payload))
    }
  }

  @Test func aLinkInTerminalOutputIsTheAppsToOpen() {
    #expect(
      openURLEvent("https://example.com/a", kind: GHOSTTY_ACTION_OPEN_URL_KIND_UNKNOWN)
        == .linkClicked("https://example.com/a")
    )
  }

  @Test func anOsc8HyperlinkIsAnEventOfItsOwnCarryingItsTarget() {
    #expect(
      openURLEvent("file:///tmp/x.txt", kind: GHOSTTY_ACTION_OPEN_URL_KIND_OSC8)
        == .hyperlinkClicked("file:///tmp/x.txt")
    )
  }

  /// libghostty opens what the app declines itself, so a kind it adds later
  /// would skip the app's rules.
  @Test func aLinkOfAKindNotYetKnownIsJudgedByTheAppNotLibghostty() {
    #expect(
      openURLEvent("/tmp/x", kind: ghostty_action_open_url_kind_e(rawValue: 99))
        == .linkClicked("/tmp/x")
    )
  }

  @Test func aReportedDirectoryIsCopiedOutAndAnEmptyOneIsUnknown() {
    func reported(_ path: String) -> GhosttySurfaceEvent? {
      path.withCString { pwd in
        var payload = ghostty_action_u()
        payload.pwd = ghostty_action_pwd_s(pwd: pwd)
        return GhosttySurfaceEvent(action(GHOSTTY_ACTION_PWD, payload))
      }
    }
    #expect(reported("/Users/me/code") == .directoryReported("/Users/me/code"))
    #expect(reported("") == .directoryReported(nil))
  }

  @Test func aLinkGhosttyNamesItselfIsLeftToLibghostty() {
    #expect(openURLEvent("file:///tmp/config", kind: GHOSTTY_ACTION_OPEN_URL_KIND_TEXT) == nil)
    #expect(openURLEvent("file:///tmp/page.html", kind: GHOSTTY_ACTION_OPEN_URL_KIND_HTML) == nil)
  }

  /// Declined, a link goes to libghostty's own `open`, unchecked.
  @Test func bothKindsOfLinkClickAndNothingElseAreLinkClicks() {
    #expect(GhosttySurfaceEvent.linkClicked("/x").isLinkClick)
    #expect(GhosttySurfaceEvent.hyperlinkClicked("file:///x").isLinkClick)
    #expect(GhosttySurfaceEvent.bell.isLinkClick == false)
    #expect(GhosttySurfaceEvent.retitled("t").isLinkClick == false)
  }
}
